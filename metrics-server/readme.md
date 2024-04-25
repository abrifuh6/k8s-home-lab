
# Step 8 (Optional): Setup Kubernetes Metrics Server

**Importance of Metrics Server:**

The Kubernetes Metrics Server is a crucial component for monitoring and autoscaling in Kubernetes clusters. It collects resource metrics such as CPU and memory usage from nodes and pods, providing valuable insights into the cluster's performance and resource utilization.

**Benefits of Metrics Server:**

- **Resource Monitoring:** The Metrics Server enables real-time monitoring of CPU and memory usage for nodes and pods, allowing operators to identify performance bottlenecks and resource constraints.
- **Autoscaling:** Metrics collected by the Metrics Server are essential for Horizontal Pod Autoscaling (HPA), which automatically adjusts the number of pod replicas based on resource metrics, ensuring optimal resource allocation and efficient utilization of cluster resources.
- **Capacity Planning:** By analyzing historical metrics data collected by the Metrics Server, operators can perform capacity planning and make informed decisions about cluster scaling and resource allocation.
- **Troubleshooting:** The Metrics Server provides valuable insights into pod and node behavior, facilitating troubleshooting and debugging efforts during incidents or performance issues.

Deploying the Metrics Server is essential for effective monitoring and management of Kubernetes clusters, enabling operators to maintain optimal performance and scalability.

---

Kubeadm doesn’t install the metrics server component during its initialization. We have to install it separately.

To verify this, if you run the `kubectl top nodes` command, you will see the "Metrics API not available" error:

```bash
kubectl top nodes
```

```bash
error: Metrics API not available
```

To install the metrics server, execute the following metric server manifest file. It deploys metrics server version v0.6.2:

```bash
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml
```

This manifest is taken from the official metrics server repo. I have added the `--kubelet-insecure-tls` flag to the container to make it work in the local setup and hosted it separately. Otherwise, you will get the following error:

```
because it doesn't contain any IP SANs" node=""
```

Once the metrics server objects are deployed, it takes a minute for you to see the node and pod metrics using the `kubectl top nodes` command:

```bash
kubectl top nodes
```

```bash
NAME           CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
controlplane   142m         7%     1317Mi          34%
node01         36m          1%     915Mi           23%
```

You can also view the pod CPU and memory metrics using the following command:

```bash
kubectl top pod -n kube-system
```

