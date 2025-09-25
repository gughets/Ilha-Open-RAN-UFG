include MakefileVars.mk

.PHONY: all clean install

##@ Utility
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Installation
deploy-core: ## Deploy Open5GS core components using Helm
	@echo "${CYAN}Deploying core components...${END}"
	@helm upgrade --install open5gs -n open5gs --create-namespace charts/open5gs -f values/values-multi-plmn.yaml
	@echo "${GREEN}Core components deployed successfully!${END}"

undeploy-core: ## Undeploy Open5GS core components
	@echo "${CYAN}Undeploying core components...${END}"
	@helm uninstall open5gs -n open5gs && kubectl delete namespace open5gs || true
	@echo "${GREEN}Core components undeployed successfully!${END}"

build-vpp-upf: ## Build Docker image for VPP-UPF
	@echo "${CYAN}Building VPP-UPF Docker image...${END}"
	@docker build -t $(VPP_UPF_IMAGE_REPO)/$(VPP_UPF_IMAGE):$(VPP_UPF_IMAGE_TAG) -f docker/vpp-upf/Dockerfile.vpp-upf .
	@echo "${GREEN}VPP-UPF Docker image built successfully!${END}"