SHELL := /bin/bash

HOSTS := /tmp/ansible-hosts
TEMP_FILE := /tmp/ansible-line

ifndef RESOURCE_PREFIX
$(error RESOURCE_PREFIX is not set, please read the README and set using .envrc.)
endif

ifndef IC_API_KEY
$(error IC_API_KEY is not set, please read the README and set using .envrc.)
endif

.PHONY: all

aggressive_clean: check_clean
	until make perform_clean; do echo 'Retrying clean...'; sleep 10; done

apply_ansible: first_etcdadm other_etcds first_master other_masters workers kube_ui 

apply_terraform: terraform_init
	echo RESOURCE_PREFIX: $(RESOURCE_PREFIX)
	echo NUM_MASTERS: $(TF_VAR_NUM_MASTERS)
	echo NUM_WORKERS: $(TF_VAR_NUM_WORKERS)
	echo CLOUD_REGION: ${TF_VAR_CLOUD_REGION}
	echo SECOND_DISK_CAPACITY: $(TF_VAR_SECOND_DISK_CAPACITY)
	(cd terraform && terraform apply -auto-approve)

check_clean:
	@echo -n "Are you sure you want to delete all resources? [y/N] " && read ans && [ $${ans:-N} = y ]

clean: check_clean terraform_init
	make perform_clean

create_join_stmt: 
	(cd ansible && ansible-playbook -v -i $(HOSTS) create-token.yaml  --key-file "../ssh-keys/ssh-key")

config_kubectl:  prep_ansible_inventory
	(cd ansible && ansible-playbook -v -i $(HOSTS) configure-kubectl.yaml -e "lb_hostname=$(shell cd terraform && terraform output lb_hostname | tr -d '"')"  --key-file "../ssh-keys/ssh-key")

etcd_reset:
	(cd ansible && ansible-playbook -v -i $(HOSTS) etcd-reset.yaml --key-file "../ssh-keys/ssh-key")

etcd_reset_other:
	(cd ansible && ansible-playbook -v -i $(HOSTS) etcd-reset-other.yaml --key-file "../ssh-keys/ssh-key")

first_etcdadm: prep_ansible_inventory 
	(cd ansible && ansible-playbook -v -i $(HOSTS) first-etcdadm.yaml  --key-file "../ssh-keys/ssh-key")

first_master: login_ibmcloud prep_ansible_inventory
	(cd ansible && ansible-playbook -v -i $(HOSTS) kube-first-master.yaml -e "lb_hostname=$(shell cd terraform && terraform output lb_hostname | tr -d '"') kubelet_port_number=$(KUBELET_PORT_NUMBER)"  --key-file "../ssh-keys/ssh-key")

get_etcd_info: prep_ansible_inventory 
	(cd ansible && ansible-playbook -v -i $(HOSTS) get-etcd-info.yaml  --key-file "../ssh-keys/ssh-key")

get_terraform_show:
	(cd terraform && terraform show -json > ../terraform_show.json)

login_ibmcloud:
	# For now, we forcibly select us-east from this list: https://cloud.ibm.com/docs/satellite?topic=satellite-sat-regions.
	ibmcloud login --apikey $(IC_API_KEY) -r us-east

other_masters: prep_ansible_inventory create_join_stmt
	(cd ansible && ansible-playbook -v -i $(HOSTS) kube-other-masters.yaml --key-file "../ssh-keys/ssh-key" -e "join='$(shell cat /tmp/join)' kubelet_port_number=$(KUBELET_PORT_NUMBER)")


install:
	ibmcloud plugin install container-registry
	ibmcloud plugin install container-service
	ibmcloud plugin install observe-service
	ibmcloud plugin install vpc-infrastructure

kube_reset:
	(cd ansible && ansible-playbook -v -i $(HOSTS) kube-reset.yaml --key-file "../ssh-keys/ssh-key")

kube_ui:  config_kubectl
	./deploy_kube_ui
	
other_etcds: get_etcd_info
	(cd ansible && ansible-playbook -v -i $(HOSTS) other-etcds.yaml  --key-file "../ssh-keys/ssh-key" -e "first_master_ip=$(shell cd terraform && terraform output first_master_ip | tr -d '"')")

perform_clean: login_ibmcloud
	cd terraform && terraform destroy -auto-approve

prep_ansible_inventory: get_terraform_show
	python prepare_ansible_inventory.py

ssh-keygen:
	mkdir -p ssh-keys/
	ssh-keygen -f ssh-keys/ssh-key
	chmod 600 ssh
	cat ssh-keys/ssh-key.pub | cut -d' ' -f2 | sed 's/^/export TF_VAR_SSH_PUBLIC_KEY="/' | sed 's/$$/"/' >> ./.envrc

ssh_master:
	ssh -i ssh-keys/ssh-key root@$(shell ./retrieve_master_ip)

terraform_refresh:
	(cd terraform && terraform refresh)


target_resource_group:
	ibmcloud target -g $(RESOURCE_PREFIX)-group

terraform_init:
ifeq (, $(shell which tfswitch))
	(cd terraform && terraform init)
else
	(cd terraform && tfswitch && terraform init)
endif

watch:
	./watch_ibmcloud $(RESOURCE_PREFIX)

workers: prep_ansible_inventory create_join_stmt
	(cd ansible && ansible-playbook -v -i "$(HOSTS)" kube-workers.yaml --key-file "../ssh-keys/ssh-key" -e "join='$(shell cat /tmp/join)' kubelet_port_number=$(KUBELET_PORT_NUMBER)")

all: login_ibmcloud
	date
	make apply_terraform
	date
	make apply_ansible
	date
	echo "Done!"
