KIND_CLUSTER_CONFIG=./local-kind-cluster/kind-cluster-config.yaml
METALLB_SCRIPT=./local-kind-cluster/metallb-configuration.sh
ARGO_HELMFILE=./local-kind-cluster/install-argo.yaml

.PHONY: all create-cluster run-helmfile configure-metallb install-argo clean help

help: ## List all available make targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: clean create-cluster run-helmfile configure-metallb install-argo ## Full setup

create-cluster: ## Create the Kind cluster
	kind create cluster --config $(KIND_CLUSTER_CONFIG)

run-helmfile: ## Run Helmfile apply
	helmfile apply

configure-metallb: ## Configure MetalLB
	bash $(METALLB_SCRIPT)

install-argo: ## Install ArgoCD using Helmfile
	helmfile apply --file $(ARGO_HELMFILE)
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

clean: ## Delete the Kind cluster
	kind delete cluster --name homelab-kind-cluster


port-forward-argo: ## Port forward ArgoCD server
	kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443


add-cluster: ## Adds k3s cluster to local cluster's argocd server
	bash ./add-k3s-cluster-to-local-cluster.sh

install-apps: ## Install apps via ArgoCD apps
	kubectl apply -f ./local-kind-cluster/apps