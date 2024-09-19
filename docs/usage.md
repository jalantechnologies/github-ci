# GitHub CI - Usage

<!-- TOC -->
* [GitHub CI - Usage](#github-ci---usage)
  * [CI](#ci)
    * [Deploying on Digital Ocean](#deploying-on-digital-ocean)
    * [Deploying on AWS](#deploying-on-aws)
  * [Clean](#clean)
<!-- TOC -->

## CI

`.github/workflows/ci.yml` - This is the main workflow with CI/CD pipeline

### Deploying on Digital Ocean

**Pre-requirements**

- Account on DigitalOcean and API token with read/write access (See [this](https://docs.digitalocean.com/reference/api/create-personal-access-token/) for help).
- Kubernetes cluster on DigitalOcean with nginx configured and mapped to domain (This example assumes - `production.myapp.com` to your load balancer. See [this](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-on-digitalocean-kubernetes-using-helm) for help.)
- Access and credentials for a Docker registry (This example uses Docker Hub - `registry.hub.docker.com`)
- A valid `Dockerfile` on root of your project with entrypoint (See [this](https://github.com/jalantechnologies/boilerplate-mern/blob/main/Dockerfile) for example).

**Note** - We also got a Terraform [project](https://github.com/jalantechnologies/platform-digitalocean-tf) for DOKS setup.

**Add - `.github/workflows/production.yml`**

```yaml
name: production

# define event on which this workflow should run
# @see - https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows
# this is an example of running the workflow when "main" branch is updated
on:
  push:
    branches:
      - main

# required permissions by this workflow
permissions:
  contents: read

jobs:
  ci:
    uses: jalantechnologies/github-ci/.github/workflows/ci.yml@v2.5
    with:
      app_name: myapp
      app_env: production
      app_hostname: 'production.myapp.com'
      branch: ${{ github.event.ref }}
      docker_registry: 'registry.hub.docker.com'
      docker_username: '<docker_username>'
      do_cluster_id: '<digital_ocean_cluster_id>'
    secrets:
      docker_password: '<docker_password>'
      do_access_token: '<digital_ocean_access_token>'
```

**Add - `lib/kube/shared/deploy.yml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
  labels:
    app: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      imagePullSecrets:
        - name: regcred
      containers:
        - name: myapp
          image: $KUBE_DEPLOYMENT_IMAGE
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  labels:
    app: myapp
spec:
  type: NodePort
  ports:
    - port: 8080
  selector:
    app: myapp
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  labels:
    app: myapp
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: $KUBE_INGRESS_HOSTNAME
      http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: myapp-service
                port:
                  number: 8080
```

**Output**

Upon successfully invocation, you will have:

- A built image pushed to your repository
- A deployment with service and ingress up and running in your Kubernetes cluster

### Deploying on AWS

**Pre-requirements**

- Account on AWS and credentials (Access key and secret). For required permissions, check [this](https://github.com/goartica/terraform-workspace-aws-projects-bionic/blob/main/iam.tf) out.
- Kubernetes cluster on AWS with nginx configured and mapped to domain (This example assumes - `production.myapp.com` to your load balancer. See [this](https://aws.amazon.com/blogs/containers/exposing-kubernetes-applications-part-3-nginx-ingress-controller/) for help.)
- Access and credentials for a Docker registry (This example uses ECR and assumes provided credentials have access to the ECR repository).
- A valid `Dockerfile` on root of your project with entrypoint (See [this](https://github.com/jalantechnologies/boilerplate-mern/blob/main/Dockerfile) for example).

**Note** - We also got a Terraform [project](https://github.com/jalantechnologies/platform-aws-tf) for EKS, ECR and IAM setup.

```yaml
name: production

on:
  push:
    branches:
      - main

permissions:
  contents: read

jobs:
  ci:
    uses: jalantechnologies/github-ci/.github/workflows/ci.yml@v2.5
    with:
      app_name: myapp
      app_env: production
      app_hostname: 'production.myapp.com'
      aws_cluster_name: '<aws_cluster_name>'
      aws_region: '<aws_region>'
      aws_use_ecr: true
      branch: ${{ github.event.pull_request.head.ref }}
    secrets:
      aws_access_key_id: '<aws_access_key_id>'
      aws_secret_access_key: '<aws_access_secret_key>'
```

## Clean

`.github/workflows/clean.yml` - This is the cleanup workflow which takes care of cleaning up resources.
