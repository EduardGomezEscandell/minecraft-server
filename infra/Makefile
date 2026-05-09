.PHONY: init plan apply

.terraform:
	terraform init -upgrade

init: .terraform

plan: init
	bash -c "source env.sh && terraform plan"

apply: init
	bash -c "source env.sh && terraform apply"

