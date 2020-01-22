# eks-terraform

Declerative EKS deployment.

Features:

- Terraform templates for EKS deployment

Todos:

- include [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- run a pod to demontrate EKS autoscaling

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

Create a secret with your AWS credentials:

```cmd
kubectl create secret aws-secret --aws_access_key_id=YOUR_AWS_ACCESS_KEY_ID --aws_secret_access_key=YOUR_AWS_SECRET_ACCESS_KEY
```

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

## To the test

The m4.large: 2 CPU and 8 GiB

Deploy an example application, e.g. [nginx-hostname](https://hub.docker.com/r/stenote/nginx-hostname/tags) returns the name of it's host.

```cmd
$ k apply -f nginx-hostname/nginx-hostname-deployment.yaml
namespace/nginx-hostname created
deployment.apps/nginx-hostname created
```

Wait untill the pod has started and forward the port:

```cmd
kubectl port-forward -n nginx-hostname nginx-hostname-77698b94b8-8q9hg 8080:80
```

And navigate to <http://localhost:8080> to find the name of the host.

## Resources

- [Terraform setup EKS](https://learn.hashicorp.com/terraform/aws/eks-intro)
- [Terraform AWS templates for EKS](https://github.com/terraform-aws-modules/terraform-aws-eks)
- [EKS ctl](https://medium.com/@Joachim8675309/building-eks-with-eksctl-799eeb3b0efd)
- [This codebase has been the starting point for the TF templates](https://github.com/terraform-providers/terraform-provider-aws/tree/master/examples/eks-getting-started)
- [autoscaler enable](https://stackoverflow.com/questions/57928941/how-can-i-configure-an-aws-eks-autoscaler-with-terraform)]
