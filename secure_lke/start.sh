#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Secure LKE Cluster Deployment"
echo "========================================="
echo ""

# Check if LINODE_TOKEN is set
if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "Please export your Linode API token:"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

# Step 1: Initialize Terraform
echo "Step 1: Initializing OpenTofu..."
tofu init
echo ""

# Step 2: Run Terraform Plan
echo "Step 2: Running tofu plan..."
tofu plan
echo ""

# Step 3: Run Terraform Apply
echo "Step 3: Running tofu apply..."
tofu apply -auto-approve
echo ""

# Step 4: Save kubeconfig
echo "Step 4: Saving kubeconfig..."
tofu output -json lke_kubeconfig | jq > kubeconfig
echo "✓ Kubeconfig saved to kubeconfig"
echo ""

# Step 5: Display cluster information
echo "Step 5: LKE Cluster deployed successfully!"
echo ""
echo "========================================="
echo "Cluster Access:"
echo "========================================="
echo "To access your cluster:"
echo "  export KUBECONFIG=\$(pwd)/kubeconfig"
echo "  kubectl get nodes"
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="

# Step 6: Deploy sample application (podinfo, echo-ip - both of them are in the config folder)
echo "Step 6: Deploying sample applications (podinfo and echo-ip)..."
export KUBECONFIG=$(pwd)/kubeconfig
kubectl apply -f config/podinfo.dpl.yaml
kubectl apply -f config/echo-ip.dpl.yaml
echo "✓ Sample applications deployed (podinfo and echo-ip)"
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="

# Step 7: Deploy load balancer services for the applications (config is in the terraform output loadbalancer_service_conf)
echo "Step 7: Deploying LoadBalancer services for the applications..."
tofu output -raw loadbalancer_service_conf | kubectl apply -f -
echo "✓ LoadBalancer services deployed for the applications"
echo ""
echo "========================================="
echo "Services Exposed!"
echo "========================================="
echo ""
echo "To get the external IPs of the services, run:"
echo "  kubectl get svc podinfo-service echo-ip-service"
echo ""
echo "You can access the applications using the external IPs assigned to the services."
echo "========================================="
echo "Secure LKE Cluster Deployment Finished!"
echo "========================================="
