# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Checks of the Terraform modules and the Terragrunt units, the same ones the
# ci workflow runs. Run them from this directory: `make -C infra test`.

TOFU       ?= tofu
TERRAGRUNT ?= terragrunt
TFDOCS     ?= terraform-docs

.PHONY: help fmt fmt-check test docs docs-check clean

help:
	@echo "Targets:"
	@echo "  make fmt        Format the modules and the Terragrunt files in place"
	@echo "  make fmt-check  Check the formatting (as the ci workflow does)"
	@echo "  make test       Run '$(TOFU) test' for every module that has a tests/ directory"
	@echo "  make docs       Regenerate the tables of the module READMEs (terraform-docs)"
	@echo "  make docs-check Fail when a module README is not up to date (as the ci workflow does)"
	@echo "  make clean      Remove caches, generated files and test leftovers"

fmt:
	$(TOFU) fmt -recursive modules
	$(TERRAGRUNT) hcl format

fmt-check:
	$(TOFU) fmt -check -recursive modules
	$(TERRAGRUNT) hcl format --check

# The tests mock the provider: no OVHcloud credential or network access is
# needed (a mocked VPS cannot be destroyed, so a test run may report it as left
# over; that is expected, see modules/vps/tests/).
test:
	@for dir in modules/*/; do \
		if [ -d "$${dir}tests" ]; then \
			echo "=== $(TOFU) test $${dir} ==="; \
			(cd "$$dir" && $(TOFU) init -backend=false -input=false > /dev/null && $(TOFU) test) || exit 1; \
		fi; \
	done

docs:
	@for dir in modules/*/; do $(TFDOCS) -c .terraform-docs.yml "$$dir" > /dev/null || exit 1; done

docs-check: docs
	git diff --exit-code -- 'modules/*/README.md'

clean:
	find . -type d \( -name .terragrunt-cache -o -name .terraform \) -prune -exec rm -rf {} +
	find . -type f \( -name 'generated_*.tf' -o -name 'errored_test.tfstate' -o -path './modules/*/.terraform.lock.hcl' \) -delete
