SHELL := /bin/bash
.DEFAULT_GOAL := help

TF        ?= terraform
TG        ?= terragrunt
TF_DIRS   := $(sort $(dir $(wildcard modules/*/main.tf))) examples/complete/
ENV       ?= dev

.PHONY: help fmt fmt-check validate lint security check plan clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

fmt: ## Format Terraform and Terragrunt files in place
	$(TF) fmt -recursive
	$(TG) hcl fmt --working-dir live

fmt-check: ## Fail if any file is not formatted
	$(TF) fmt -check -recursive
	$(TG) hcl fmt --check --working-dir live

validate: ## terraform init -backend=false + validate for every module and example
	@set -e; for d in $(TF_DIRS); do \
		echo "==> $$d"; \
		$(TF) -chdir=$$d init -backend=false -input=false >/dev/null; \
		$(TF) -chdir=$$d validate; \
	done
	cd live && $(TG) hcl validate --inputs

lint: ## Run tflint against every module and example
	tflint --init --config=$(CURDIR)/.tflint.hcl
	@set -e; for d in $(TF_DIRS); do \
		echo "==> $$d"; \
		tflint --chdir=$$d --config=$(CURDIR)/.tflint.hcl; \
	done

security: ## Static security scan with trivy
	trivy config --severity HIGH,CRITICAL --exit-code 1 --ignorefile .trivyignore --skip-dirs '**/.terraform' --skip-dirs '**/.terragrunt-cache' .

check: fmt-check validate lint security ## Everything CI runs

plan: ## terragrunt plan for every unit in ENV (default: dev)
	cd live/$(ENV) && $(TG) run --all plan

clean: ## Remove local Terraform/Terragrunt caches
	find . -type d \( -name .terraform -o -name .terragrunt-cache \) -prune -exec rm -rf {} +
	find . -name .terraform.lock.hcl -delete
