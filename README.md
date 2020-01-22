# eks-terraform

Declerative EKS deployment.

This README features a description how to:

- apply an EKS deployment with Terraform
- deploy [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- demontrate EKS autoscaling with a simple deployment

## Deploy EKS

Infrastructure as Code: Automated deployment is done with Hashicorps' [Terraform](https://www.terraform.io/); as an alternative, I could have opted for CloudFormation which covers almost all bits and pieces of AWS. BUT Terraform covers the most important AWS resources, including EKS+autoscaling. On top of that, Terraform can provision infrastructure at OTHER cloud providers and as such prevents a vendor lock-in.

What you need in advance to run this deployment:

- Terraform CLI version 0.12.19 installed locally (e.g. `brew install terraform` on a Mac or look [here](https://learn.hashicorp.com/terraform/getting-started/install.html))
- Kubectl [installed locally](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) installed and configured with credentials.

The templates can be found in the `terraform` directory, using the [Terraform-AWS-EKS module](https://github.com/terraform-aws-modules/terraform-aws-eks). Initialize modules, plugins, etc and plan the deployment:

```cmd
cd terraform
terrafrom init
terraform plan
```

Deploy the config with:

```cmd
terraform apply
```

This takes about 20 minutes, which is really slow compared to GKE (3 minutes) and AKS (~10 minutes).

Configure kubectl:

```cmd
mv kubeconfig_dobdata-eks-demo-cluster ~/.kube/config-aws
export KUBECONFIG=$KUBECONFIG:~/.kube/config-aws
kubectl config use-context aws-dobdata-eks-demo-cluster
```

Verify the deployment and the kubectl config:

```cmd
$ kubectl get nodes
NAME                                       STATUS   ROLES    AGE   VERSION
ip-10-0-4-175.eu-west-1.compute.internal   Ready    <none>   58s   v1.14.8-eks-b8860f
ip-10-0-5-197.eu-west-1.compute.internal   Ready    <none>   57s   v1.14.8-eks-b8860f
```

## Setup autoscaling

The cluster autoscaler adjusts the size of the Kubernetes cluster when there are insufficient resources to place a pod, or when the cluster is underutilized for an specified period of time.

To [enabling autoscaling](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/autoscaling.md) configure and apply the following settings to the `dworker_groups` in the `eks` module in the `terraform/main.tf` file:

```yml
worker_groups = [{
      ...
    asg_min_size        = 1
    asg_max_size        = 5
    autoscaling_enabled = true
    protect_from_scale_in = true
}]
```

We also need to install the [cluster-autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler) into the cluster. The easiest way is to deploy [the available Helm chart](https://github.com/helm/charts/tree/master/stable/cluster-autoscaler). But when initialized, the server side of Helm, Tiller, runs in your cluster with full admin rights, which is undeniable a security issue. [The method of Tobias Bradtke](https://blog.giantswarm.io/what-you-yaml-is-what-you-get/) is to use Helm locally to render the templates as manifests to deploy. for these operations bash files are available.

Fetch the charts and the default values file:

````cmd
$ ./cluster-autoscaler/fetch.sh
FETCH CHARTS
```

Render the charts to manifests with custom values. Note that the value file contains 

```cmd
$ ./cluster-autoscaler/render.sh
RENDER MANIFESTS
wrote /Users/joostdobken/eks-terraform/cluster-autoscaler/manifests/cluster-autoscaler/templates/pdb.yaml
wrote /Users/joostdobken/eks-terraform/cluster-autoscaler/manifests/cluster-autoscaler/templates/serviceaccount.yaml
wrote /Users/joostdobken/eks-terraform/cluster-autoscaler/manifests/cluster-autoscaler/templates/clusterrole.yaml
wrote /Users/joostdobken/eks-terraform/cluster-autoscaler/manifests/cluster-autoscaler/templates/clusterrolebinding.yaml
wrote /Users/joostdobken/eks-terraform/cluster-autoscaler/manifests/cluster-autoscaler/templates/role.yaml
wrote /Users/joostdobken/eks-terraform/cluster-autoscaler/manifests/cluster-autoscaler/templates/rolebinding.yaml
wrote /Users/joostdobken/eks-terraform/cluster-autoscaler/manifests/cluster-autoscaler/templates/service.yaml
wrote /Users/joostdobken/eks-terraform/cluster-autoscaler/manifests/cluster-autoscaler/templates/deployment.yaml
```

Deploy the manifests to the cluster:

```cmd
$ ./cluster-autoscaler/deploy.sh
DEPLOY MANIFESTS
clusterrole.rbac.authorization.k8s.io/cluster-autoscaler-aws-cluster-autoscaler created
clusterrolebinding.rbac.authorization.k8s.io/cluster-autoscaler-aws-cluster-autoscaler created
deployment.apps/cluster-autoscaler-aws-cluster-autoscaler created
poddisruptionbudget.policy/cluster-autoscaler-aws-cluster-autoscaler created
role.rbac.authorization.k8s.io/cluster-autoscaler-aws-cluster-autoscaler created
rolebinding.rbac.authorization.k8s.io/cluster-autoscaler-aws-cluster-autoscaler created
service/cluster-autoscaler-aws-cluster-autoscaler created
serviceaccount/cluster-autoscaler-aws-cluster-autoscaler created
````

## auto-scaling in practice

Deploy an example application, e.g. [nginx-hostname](https://hub.docker.com/r/stenote/nginx-hostname/tags) returns the name of the host container.

```cmd
$ k apply -f nginx-hostname/nginx-hostname-deployment.yaml
namespace/nginx-hostname created
deployment.apps/nginx-hostname created
```

Wait untill the pod has started and forward the port:

```cmd
kubectl port-forward -n nginx-hostname $(kubectl get pod -n nginx-hostname -o jsonpath="{.items[0].metadata.name}") 8080:80
```

In another shell, get the name of the host running the pod:

```cmd
$ curl localhost:8080
nginx-hostname-798c6f6564-7bsd8 | v1.0
```

That is not really spectacular, but this brings us to the point where we can demonstrate how auto-scaling works. The deployment of the nginx-hostname includes requested resources:

```yml
...
    resources:
      requests:
        memory: "4GiB"
        cpu: "1050m"
```

That is definitely an overkill of resources for such a simple pod; but since the m4.large instances only have 2 CPU and 8 GiB Memory, two of these pods will never be deployed on 1 machine.

### Upscaling

We can increase the number of replicas to 3 in the file `nginx-hostname/nginx-hostname-deployment.yaml` and run `k apply -f nginx-hostname/nginx-hostname-deployment.yaml`.

```cmd
$ kubectl get po -n nginx-hostname -o wide -w
NAME                              READY   STATUS    RESTARTS   AGE     IP          NODE                                       NOMINATED NODE   READINESS GATES
nginx-hostname-5cfbfcfbd7-fkmcb   1/1     Running   0          39s     10.0.4.16   ip-10-0-4-175.eu-west-1.compute.internal   <none>           <none>
nginx-hostname-5cfbfcfbd7-n5vk2   1/1     Running   0          4m57s   10.0.5.28   ip-10-0-5-197.eu-west-1.compute.internal   <none>           <none>
nginx-hostname-5cfbfcfbd7-t896q   0/1     Pending   0          6s      <none>      <none>                                     <none>           <none>
```

Currently the third pod cannot be placed on any machine. If you wait one minute (or two), if auto-scaling is correctly configured, the last pod will change status to "Running". When we check the number of nodes:

```cmd
$ k get no
NAME                                       STATUS   ROLES    AGE    VERSION
ip-10-0-4-175.eu-west-1.compute.internal   Ready    <none>   147m   v1.14.8-eks-b8860f
ip-10-0-5-197.eu-west-1.compute.internal   Ready    <none>   159m   v1.14.8-eks-b8860f
ip-10-0-6-188.eu-west-1.compute.internal   Ready    <none>   5m4s   v1.14.8-eks-b8860f
```

There are three instances! I experienced that the up-scaling latency is really only 30 to 60 seconds. Increase the number of replicas to 6 and apply it to the cluster. When after one or two minutes, we check the number of pods:

![Screenshot of the six pods](images/screenshot_six_pods.png)

There is still one pending pod. This is expected behavior, because we have indicated in the file `terraform/main.tf` that the worker group can scale up to a maximum of 5 instances (variable `asg_max_size`).

### Downscaling

Change the number of replicas back to 2\. We expect the following behavior:

- first the number of nginx-hostname pods will be reduced to two;
- autoscaling detects that the load on the cluster is reduced and shuffling of pods is possible;
- three of the five instances are terminated.

The latency to scale down is is about 10 minutes, much longer than for upscaling. Some cooldown perio for scalingdown is certainly desired to deal with volatility in demand. But one can tune this settings in the `cluster-autoscaler/values/cluster-autoscaler.yaml` file.

## Resources

- [Terraform AWS templates for EKS](https://github.com/terraform-aws-modules/terraform-aws-eks)
