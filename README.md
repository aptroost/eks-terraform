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

Initialize modules, plugins, etc and plan the deployment:

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
terraform output kubeconfig>~/.kube/config-aws
export KUBECONFIG=$KUBECONFIG:~/.kube/config-aws
kubectl config use-context aws
```

Verify the deployment and the kubectl config:

```cmd
$ kubectl get nodes
NAME                                       STATUS   ROLES    AGE   VERSION
ip-10-0-1-132.eu-west-1.compute.internal   Ready    <none>   65m   v1.14.7-eks-1861c5
```

Allow the worker nodes networking access to the EKS master cluster:

```cmd
terraform output config_map_aws_auth > configmap.yml
kubectl apply -f configmap.yml
```

## Setup autoscaling

TODO

## Resources

- [Terraform setup EKS](https://learn.hashicorp.com/terraform/aws/eks-intro)
- [Terraform AWS templates for EKS](https://github.com/terraform-aws-modules/terraform-aws-eks)
- [EKS ctl](https://medium.com/@Joachim8675309/building-eks-with-eksctl-799eeb3b0efd)
- [This codebase has been the starting point for the TF templates](https://github.com/terraform-providers/terraform-provider-aws/tree/master/examples/eks-getting-started)
