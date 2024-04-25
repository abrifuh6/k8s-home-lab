# Testing My Kubernetes Cluster

This file defines a Kubernetes deployment for a web application using the custom Nginx image `buamtech/custom-nginx:1.0.0`, and a service to expose this deployment using a LoadBalancer, which in your case will be handled by MetalLB, an on-premises load balancer solution for Kubernetes.


## Web Application Deployment in Kubernetes

This README describes the process of deploying a web application using a custom Nginx image on a Kubernetes cluster. This setup utilizes MetalLB, an on-premises load balancer, to expose the service.

### Prerequisites

- A Kubernetes cluster with MetalLB installed and configured.
- `kubectl` command line tool installed on your local machine or wherever you manage the cluster from.
- Permissions to deploy resources to the Kubernetes cluster.
- `nginx-deployment.yaml`: Contains the Kubernetes Deployment and Service definitions.

### Deployment Steps

1. **Clone the Repository**

   Make sure you have the `nginx-deployment.yaml` file available in your workspace.

2. **Deploy the Application**

   Apply the Kubernetes configurations:

   ```bash
   kubectl apply -f nginx-deployment.yaml
   ```

3. **Verify the Deployment**

   Check the status of the deployment:

   ```bash
   kubectl get deployments
   kubectl get pods
   ```

   Ensure that the pods are running without errors.

4. **Access the Web Application**

   Retrieve the external IP assigned by MetalLB to access the web application:

   ```bash
   kubectl get services
   ```

   Look for the external IP associated with the `web-app` service and navigate to it using your web browser.

5. **Troubleshooting**

   If you encounter issues, check the logs of the Nginx pod:

   ```bash
   kubectl logs <pod_name>
   ```

   Additionally, ensure MetalLB is configured correctly to allocate IPs from the defined range.
