#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='abcd'
export password='abcd'
export tenantId='abcd'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export appClonedRepo='https://github.com/zaidmohd/azure_arc'
export namespace='hello-arc'

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI
echo "Installing Azure CLI"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Installing required Azure Arc CLI extensions
az extension add --name connectedk8s
az extension add --name k8s-configuration

# Login to Azure
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Registering Azure Arc providers
echo "Registering Azure Arc providers"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

az provider show -n Microsoft.Kubernetes -o table
az provider show -n Microsoft.KubernetesConfiguration -o table
az provider show -n Microsoft.ExtendedLocation -o table

# Create a namespace for your ingress and app resources
kubectl create ns $namespace

# Create GitOps config for NGINX Ingress Controller
echo "Creating GitOps config for NGINX Ingress Controller"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name cluster-helm-config-nginx \
--namespace $namespace \
--cluster-type connectedClusters \
--scope cluster \
--url $appClonedRepo \
--branch master --sync-interval 3s \
--kustomization name=nginx path=./artifacts/hello-arc/releases/nginx

# Checking if Ingress Controller is ready
until kubectl get service/nginx-ingress-ingress-nginx-controller --namespace $namespace --output=jsonpath='{.status.loadBalancer}' | grep "ingress"; do echo "Waiting for NGINX Ingress controller external IP..." && sleep 20 ; done

# Create GitOps config for App Deployment
echo "Creating GitOps config for Hello-Arc App"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name namespace-helm-config-app \
--namespace $namespace \
--cluster-type connectedClusters \
--scope namespace \
--url $appClonedRepo \
--branch master --sync-interval 3s \
--kustomization name=app path=./artifacts/hello-arc/releases/app
