.PHONY: init plan apply

.terraform:
	terraform init -upgrade

init: .terraform

plan: init
	bash -c "source .env && terraform plan"

apply: init
	bash -c "source .env && terraform apply"

