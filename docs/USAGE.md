# GitHub CI - Usage

<!-- TOC -->
* [GitHub CI - Usage](#github-ci---usage)
  * [CI](#ci)
    * [Deploying on Digital Ocean](#deploying-on-digital-ocean)
    * [Deploying on AWS](#deploying-on-aws)
    * [Configuring the Build](#configuring-the-build)
    * [Defining Kubernetes Resources](#defining-kubernetes-resources)
    * [Hostname and TLS](#hostname-and-tls)
    * [Adding Hooks](#adding-hooks)
    * [Enabling SonarQube Analysis](#enabling-sonarqube-analysis)
    * [Enabling Checks](#enabling-checks)
    * [Controlling Concurrency](#controlling-concurrency)
    * [Running on Branches and PullRequest](#running-on-branches-and-pullrequest)
    * [Injecting Configuration using Doppler](#injecting-configuration-using-doppler)
    * [Reference](#reference)
  * [Clean](#clean)
    * [Cleaning up on DigitalOcean](#cleaning-up-on-digitalocean)
    * [Cleaning up on AWS](#cleaning-up-on-aws)
    * [Adding Hooks](#adding-hooks-1)
    * [Reference](#reference-1)
<!-- TOC -->

## CI

`.github/workflows/ci.yml` - This is the main workflow with CI/CD pipeline

### Deploying on Digital Ocean

**Pre-requirements**

- Account on DigitalOcean and API token with read/write access (See [How to Create a Personal Access Token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) for help).
- Kubernetes cluster on DigitalOcean with nginx configured and mapped to domain (This example assumes - `production.myapp.com` is mapped to your load balancer. See [How To Set Up an Nginx Ingress on DigitalOcean Kubernetes Using Helm](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-on-digitalocean-kubernetes-using-helm) for help.)
- Access and credentials for a Docker registry (This example uses Docker Hub - `registry.hub.docker.com` and assumes provided credentials have access to the repository named - `myapp`)
- A valid `Dockerfile` on root of your project with entrypoint (See [Dockerfile](https://github.com/jalantechnologies/boilerplate-mern/blob/main/Dockerfile) for example).

**Tip** - We also got [platform-digitalocean-tf](https://github.com/jalantechnologies/platform-digitalocean-tf) Terraform project for DOKS setup.

**Tip** - For more examples and end-to-end setup, see workflows for our [MERN Boilerplate](https://github.com/jalantechnologies/boilerplate-mern/tree/main/.github/workflows).

**Example**

```yaml
# .github/workflows/production.yml

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

```yaml
# lib/kube/shared/app.yml

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

- Account on AWS and credentials (Access key and secret). For required permissions, see [iam.tf](https://github.com/jalantechnologies/platform-aws-tf/blob/main/iam.tf).
- Kubernetes cluster on AWS with nginx configured and mapped to domain (This example assumes - `production.myapp.com` is mapped to your load balancer. See [Exposing Kubernetes Applications, Part 3: Ingress-Nginx Controller](https://aws.amazon.com/blogs/containers/exposing-kubernetes-applications-part-3-nginx-ingress-controller/) for help.)
- Access and credentials for a Docker registry (This example uses ECR and assumes provided credentials have access to the ECR repository named - `myapp`).
- A valid `Dockerfile` on root of your project with entrypoint (See [Dockerfile](https://github.com/jalantechnologies/boilerplate-mern/blob/main/Dockerfile) for example).

**Tip** - We also got [platform-aws-tf](https://github.com/jalantechnologies/platform-aws-tf) Terraform project for EKS, ECR and IAM setup.

```yaml
# .github/workflows/production.yml

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

**Output**

Upon successfully invocation, you will have:

- A built image pushed to your repository
- A deployment with service and ingress up and running in your Kubernetes cluster

### Configuring the Build

- Use `build_context` parameter for changing the [build context](https://docs.docker.com/build/concepts/context/). By default, workflow builds from root of the repository.
- Use `build_args` parameter for sending build arguments to the build.
- Use `build_secrets` for using sensitive config to the build. See [Using secrets with GitHub Actions](https://docs.docker.com/build/ci/github-actions/secrets/).
- The build step uses the value for `app_name` parameter to obtain repository name.

**Example**

```yaml
# .github/workflows/production.yml

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
      build_args: |
        CI=true
        NODE_ENV=production
      build_context: apps/backend
    secrets:
      build_secrets: |
        github_token=${{ secrets.GITHUB_TOKEN }}
```

```dockerfile
# apps/backend/Dockerfile

FROM node:20.11.1-buster

RUN --mount=type=secret,id=github_token,env=GITHUB_TOKEN

ARG CI
ARG NODE_ENV

RUN npm ci

RUN npm run build

CMD [ "npm", "start" ]
```

**Authenticating with Docker Registry**

For authentication, following parameters are supported:

| Name            | Type   | Description                                                                                                       |
|-----------------|--------|-------------------------------------------------------------------------------------------------------------------|
| docker_registry | input  | Registry to use with docker images. By default it uses Docker Hub (registry.hub.docker.com)                       |
| docker_username | input  | Username for authenticating with docker, see [docker login](https://docs.docker.com/reference/cli/docker/login/). |
| docker_password | secret | Password for authenticating with docker, see [docker login](https://docs.docker.com/reference/cli/docker/login/). |

Using these parameters, workflow then creates a `Secret` with name `regcred` in default namespace which deployments can use to pull built images:

```yaml
# lib/kube/shared/app.yml

apiVersion: apps/v1
kind: Deployment
spec:
  spec:
    imagePullSecrets:
      - name: regcred
    containers:
      - name: myapp
        image: $KUBE_DEPLOYMENT_IMAGE
```

**Using ECR**

If [ECR](https://aws.amazon.com/ecr/) support is required, it can be used in following ways:

- Using AWS credentials - The recommended method fo using ECR where simply setting `aws_use_ecr` parameter to `true.` It will then simply use the provided AWS credentials (`aws_access_key_id`, `aws_secret_access_key`) to authenticate with the registry.
- Using Docker credentials - Simply generating docker credentials against ECR works but AWS does not allow long-lived tokens to be generated. This method is not recommended.

When using AWS credentials, EKS role is used directly to pull docker images. See [Using Amazon ECR Images with Amazon EKS](https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_on_EKS.html) on how it works.

**Caching**

- When building - Make sure `Dockerfile` is set up in the way layers can be cached, see [Docker build cache](https://docs.docker.com/build/cache/).
- This workflow uses the experimental [GitHub Cache](https://docs.docker.com/build/ci/github-actions/cache/#github-cache) as cache store for managing the cache.
- Cache works on multiple levels. By default - The builds are always cached per branch. But in case a `base` is present, it can also use the base branch for obtaining caches. Useful when working with Pull Requests.

### Defining Kubernetes Resources

- Kubernetes resources are applied using `kubectl apply -f` from `yaml` files.
- Workflow by default looks in `lib/kube` directory from root for specification files. This can be changed via `deploy_root` parameter.

**Directory Structure**

Directory defined in `deploy_root` parameter needs to have the following structure which is recognized by the workflow:

- `core` - Define Kubernetes resources which are to be applied in all environments but should be excluded from clean up (see - [Clean](#clean))
- `shared` - Define Kubernetes resources which are to be applied in all environments and should be included in cleanup.
- `<app_env>` - Define Kubernetes resources in this directory which are only applied based on the value for `app_env` input.

**Examples**

```yaml
# lib/kube/core/secret.yml
# this will always get applied + excluded from cleanup

apiVersion: v1
kind: Secret
metadata:
  name: dotfile-secret
data:
  .secret-file: dmFsdWUtMg0KDQo=
```

```yaml
# lib/kube/staging/app.yml
# this will only get applied if app_env = staging

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
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: doks.digitalocean.com/node-pool
                    operator: In
                    values:
                      - cluster-staging-pool
      imagePullSecrets:
        - name: regcred
      containers:
        - name: myapp
          image: $KUBE_DEPLOYMENT_IMAGE
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
```

```yaml
# lib/kube/production/app.yml
# this will only get applied if app_env = production

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
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: doks.digitalocean.com/node-pool
                    operator: In
                    values:
                      - cluster-production-pool
      imagePullSecrets:
        - name: regcred
      containers:
        - name: myapp
          image: $KUBE_DEPLOYMENT_IMAGE
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
```

```yaml
# lib/kube/shared/app.yml
# this will always get applied + marked for cleanup

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

**Placeholders**

Following placeholders are available for use within Kubernetes specifications:

| Key                         | Description                                                                                                                                                | Example                                                    |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------|
| DOCKER_REGISTRY             | Provided docker registry. See [Configuring the Build](#configuring-the-build).                                                                             | `registry.hub.docker.com`                                  |
| DOCKER_USERNAME             | Provided docker username. See [Configuring the Build](#configuring-the-build).                                                                             | `myusername`                                               |
| DOCKER_PASSWORD             | Provided docker password. See [Configuring the Build](#configuring-the-build).                                                                             | `mypassword`                                               |
| DOPPLER_MANAGED_SECRET_NAME | Name of the doppler Kubernetes secret the can be used in deployments. See [Injecting Configuration using Doppler](#injecting-configuration-using-doppler). | `doppler-myapp-production-managed-secret`                  |
| KUBE_ROOT                   | Value for `deploy_root` input.                                                                                                                             | `lib/kube`                                                 |
| KUBE_NS                     | Combination of `app_name` and `app_env` inputs.                                                                                                            | `myapp-production`                                         |
| KUBE_APP                    | Combination of `app_name` and `app_env` inputs with branch ID. See [Running on Branches and PullRequest](#running-on-branches-and-pullrequest).            | `myapp-production-6905caad90e785f`                         |
| KUBE_ENV                    | Value for `app_env` input.                                                                                                                                 | `production`                                               |
| KUBE_DEPLOYMENT_IMAGE       | Reference to the built image. Can be directly used with `spec.containers.image` in Kubernetes deployment specifications.                                   | `registry.hub.docker.com/myusername/myapp@sha256:b5a3a...` |
| KUBE_INGRESS_HOSTNAME       | Generated value based on `app_host` input. See [Hostname and TLS](#hostname-and-tls).                                                                      | `production.myapp.com`                                     |
| KUBE_DEPLOY_ID              | Unique ID based on `run_number` provided by GitHub.                                                                                                        | `230`                                                      |

All environment variables exposed by GitHub actions are also available. See [here](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables#default-environment-variables) for the list.

**Example**

```yaml
# lib/kube/shared/app.yml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
  labels:
    app: myapp
    deploy_id: $DEPLOY_ID
    event: $GITHUB_EVENT_NAME
spec:
#  ...
```

**Labeling**

On every workflow run, following labels are applied to every resource that is being applied:

- `gh/workflow-version` - Workflow version being used (example - `v2.5`)
- `gh/workflow-run` - Combination of run information provided by GitHub in format - `run_id-run_number-run_attempt`. See [GitHub Context](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/accessing-contextual-information-about-workflow-runs#github-context) for more info.
- `gh/actor` - Username of the person who initiated the workflow. Lookup `GITHUB_ACTOR` [here](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables#default-environment-variables) for more info.
- `gh/commit` - The commit SHA that triggered the workflow. Lookup `GITHUB_SHA` [here](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables#default-environment-variables) for more info.

**Tip** - See [kubectl apply](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_apply/) to see how `apply` works and how file input is processed.

### Hostname and TLS

- The workflow accepts `app_hostname` parameter for injecting hostname values.
- Kubernetes specifications can use `KUBE_INGRESS_HOSTNAME` placeholders to inject hostname. See [Defining Kubernetes Resources](#defining-kubernetes-resources) for more info.

**Example**

```yaml
# lib/kube/shared/app.yml
# app_hostname = production.myapp.com

apiVersion: networking.k8s.io/v1
kind: Ingress
spec:
  rules:
    - host: $KUBE_INGRESS_HOSTNAME # will get replaced with "production.myapp.com"
```

**Wildcard Support**

The input can also accept placeholders as well to allow environment or branch based deployments. The supported placeholders are:

- `{0}` - Value for `app_env` parameter.
- `{1}` - Branch ID generated from provided branch. See [Running on Branches and PullRequest](#running-on-branches-and-pullrequest) for more info.

**Example**

```yaml
# lib/kube/shared/app.yml
# app_hostname = {0}.myapp.com
# app_env = staging

apiVersion: networking.k8s.io/v1
kind: Ingress
spec:
  rules:
    - host: $KUBE_INGRESS_HOSTNAME # will get replaced with "staging.myapp.com"
```

To support wildcards, following entry can be added as DNS records, assuming that DNS provider supports use of wildcards:

```
Type: A       Hostname: *.myapp.com       Value: <nginx_load_balancer_ip>
```

**TLS**

For TLS, this example uses Cert Manager with LetsEncrypt. See this for [setup](https://cert-manager.io/docs/tutorials/acme/nginx-ingress/) guide.

```yaml
# lib/kube/shared/app.yml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  labels:
    app: myapp
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: "<cluster_issuer_name>"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - $KUBE_INGRESS_HOSTNAME
      secretName: myapp-cert-key
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

### Adding Hooks

- Workflow supports running bash scripts as hooks during deployment lifecycle.
- Hooks can be defined under `scripts` directory residing within `deploy_root` parameter (So for example, if `deploy_root` = `lib/kube`, workflow will look for hooks under `lib/kube/scripts` directory).
- If the hook fails with non 0 error code, it will fail the workflow run.
- The bash scripts have same variables available for usage as same as Kubernetes resources, see [Defining Kubernetes Resources](#defining-kubernetes-resources) for list.

**Available Hooks**

- `pre-deploy.sh` - Hook to be run before any Kubernetes resources are applied.
- `post-deploy.sh` - Hook to be run after all Kubernetes resources have been applied.

**Example**

```shell
#!/bin/bash
# lib/kube/scripts/post-deploy.sh
# this script waits for deployment to succeed
# in case status could not be verified, the script would fail, thus failing the workflow run

kubectl rollout status deploy/"$KUBE_APP"-deployment -n "$KUBE_NS"
```

### Enabling SonarQube Analysis

- Workflow supports running static code analyser using [SonarQube](https://www.sonarsource.com/products/sonarqube/)
- Analysis is only run when `sonar_host_url` input is provided.
- The analysis waits on configured [Quality Gate](https://docs.sonarsource.com/sonarqube/latest/user-guide/quality-gates/) to provide results. If the check fails, it fails the check named `analyze`.

**Parameters**

| Name                | Type   | Description                                                                |
|---------------------|--------|----------------------------------------------------------------------------|
| sonar_host_url      | input  | URL to SonarQube instance                                                  |
| sonar_token         | secret | API token for accessing SonarQube instance                                 |
| branch              | input  | Branch from which this workflow was run. See _Analysis Modes_ below.       |
| analyze_base        | input  | Base branch for running incremental analysis. See _Analysis Modes_ below.  |
| pull_request_number | input  | Pull request number to be used for providing incremental analysis details. |

**Analysis Modes**

The SonarQube analysis can run in following modes:

- Incremental Analysis
  - Analysis to be run on new code being added, usually run on short-lived branches other than `main`.
  - This analysis is only run if `analyze_base` parameter was provided.
  - This analysis also uses `pull_request_number` if provided to provide analysis results.
  - See [Branch Analysis](https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/branch-analysis/introduction/) and [Pull Request Analysis](https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/pull-request-analysis/introduction/) for more info.

- Full Analysis
  - Analysis to be run on whole code, usually run on long-lived branches like `main`.
  - This analysis is only run if `analyze_base` parameter was not provided.

### Enabling Checks

- Workflow can also run checks such as test, lint etc. against the built image.
- The `checks` parameter can be used to enable checks. The input accepts encoded json array of string values, example - `['npm:lint', 'compose:test', 'compose:e2e']`.
- Each entry here can in the format - `scheme:input`, where:
  - `scheme` = `npm` - Can run the `input` script against `npm` to run the check. Basically `npm run input`.
    Example - `npm:lint` will run `npm run lint` against the built docker image.
  - `scheme` = `compose` - Can run the compose file with name `docker-compose.<input>.yml` to run the check. Useful for running the check a check with dependencies.
    Example - `compose:test` will run `docker compose -f docker-compose.test.yml`. For this to work as expected, make sure `services.app.image` is same as `app_name` input.
    See [docker-compose.test.yml](https://github.com/jalantechnologies/boilerplate-mern/blob/main/docker-compose.test.yml) for example.

**Generating Coverage Report**

- Running checks also supports reporting code coverages on Pull Request using [Code Coverage Summary](https://github.com/irongut/CodeCoverageSummary).
- This also makes sure to fail the check if code coverage falls within configured thresholds. The default threshold is `60 80`. See [thresholds](https://github.com/irongut/CodeCoverageSummary?tab=readme-ov-file#thresholds).
- To enable code coverage, simply dump coverage report in _Cobertura_ format to `/app/output/coverage.xml` the check would pick it up. Check [docker-compose.test.yml](https://github.com/jalantechnologies/boilerplate-mern/blob/main/docker-compose.test.yml) out for an example.
- If no file is presented, this step is simply ignored.

### Controlling Concurrency

- Ideally you'd want to run only one instance of the CI workflow to run for a branch.
- The concurrency control is in hands of the caller - The workflow itself does not control it.
- Read [Control the concurrency of workflows and jobs](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs) for more info.

**Examples**

```yaml
# .github/workflows/production.yml
# this workflow only allow a single invocation on the main branch
# this would cancel existing running workflow if there's a new push

name: production

on:
  push:
    branches:
      - main

jobs:
  ci:
    uses: jalantechnologies/github-ci/.github/workflows/ci.yml@v2.5
    concurrency:
      group: ci-production-${{ github.event.ref }}
      cancel-in-progress: true
    with:
    # ...
    secrets:
    # ...
```

```yaml
# .github/workflows/pull_request.yml
# this workflow only allow a single invocation on the pull request head branch
# this would cancel existing running workflow if there's a new push

name: pull_request

on:
  pull_request:
    types: [ opened, synchronize, reopened ]

jobs:
  ci:
    uses: jalantechnologies/github-ci/.github/workflows/ci.yml@v2.5
    concurrency:
      group: ci-pull-request-${{ github.event.pull_request.head.ref }}
      cancel-in-progress: true
    with:
    # ...
    secrets:
    # ...
```

### Running on Branches and PullRequest

The workflow's advanced runtime configuration also makes it useful for deploying short-lived deployments for feature branches.
Here's a deployment specification for reference which utilizes configuration provided by the workflow, making it suitable for deploying a short-lived app for a branch:

**Example**

```yaml
# .github/workflows/preview.yml
name: preview

on:
  pull_request:
    types: [ opened, synchronize, reopened ]

# required permissions by this workflow
permissions:
  contents: read
  pull-requests: write

jobs:
  preview:
    # only run when updating an 'Open' PR
    if: github.event.pull_request.state == 'open'
    uses: jalantechnologies/github-ci/.github/workflows/ci.yml@v2.5
    with:
      app_name: myapp
      app_env: preview
      app_hostname: '{1}.preview.myapp.com'
      branch: ${{ github.event.pull_request.head.ref }}
      docker_registry: 'registry.hub.docker.com'
      docker_username: '<docker_username>'
      pull_request_number: ${{ github.event.number }}
      do_cluster_id: '<digital_ocean_cluster_id>'
    secrets:
      docker_password: '<docker_password>'
      do_access_token: '<digital_ocean_access_token>'
```

```yaml
# lib/kube/shared/app.yml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: $KUBE_APP-deployment
  namespace: $KUBE_NS
  labels:
    app: $KUBE_APP
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $KUBE_APP
  template:
    metadata:
      labels:
        app: $KUBE_APP
    spec:
      imagePullSecrets:
        - name: regcred
      containers:
        - name: $KUBE_APP
          image: $KUBE_DEPLOYMENT_IMAGE
          imagePullPolicy: Always
          resources:
            requests:
              memory: '256Mi'
            limits:
              memory: '512Mi'
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: $KUBE_APP-service
  namespace: $KUBE_NS
  labels:
    app: $KUBE_APP
spec:
  type: NodePort
  ports:
    - port: 8080
  selector:
    app: $KUBE_APP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $KUBE_APP-ingress
  namespace: $KUBE_NS
  labels:
    app: $KUBE_APP
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
                name: $KUBE_APP-service
                port:
                  number: 8080
---
```

- `KUBE_NS` is available in `app_name-app_env` format. This is a Kubernetes namespace created by the workflow which can be useful for grouping resources together / environment and application.
- `KUBE_APP` is available in `app_name-app_env-branch_id` format, making it useful for defining resources for each branch that is provided. See **Branch ID** below.
- `KUBE_INGRESS_HOSTNAME` is available in `branch_id.preview.myapp.com` format, making it useful for to be used as hostname for each branch that is provided. See **Branch ID** below.

**Branch ID**

- This is a unique ID generated by the workflow for every branch.
- The branch name is obtained from `branch` parameter.
- The format is based on the `sha1sum` output.

**Pull Request**

- When building against a Pull Request, the workflow also supports providing the link to the deployed app using a GitHub comment.
- For this to work, `permissions.pull-requests` with `write` permissions and `pull_request_number` parameter is required.
- To turn this off, set `deploy_annotate_pr` parameter to `false`.

Example:

```text
Deployment (boilerplate-mern) is available at - https://a191a6e8889fc35.preview.platform.jalantechnologies.com
```

### Injecting Configuration using Doppler

- The workflow supports injecting application configuration via [Doppler](https://www.doppler.com/)
- For this integration to work, install [Doppler Kubernetes Operator](https://docs.doppler.com/docs/kubernetes-operator).
- The workflow basically sets up the [DopplerSecret CRD](https://docs.doppler.com/docs/kubernetes-operator#dopplersecret-crd) based on provided `app_name`, `app_env` using the `doppler_token`.
  - `app_name` - Doppler project name
  - `app_env` - Doppler environment name
  - `doppler_token` - Service token authorized to read the obtained configuration
- See the example [Deployment](https://docs.doppler.com/docs/kubernetes-operator#deployments) on how to use secrets with the deployment.

**Example**

On Doppler, say you have a project with name `myapp` and an environment with name `production`. You can inject configuration via:

```yaml
# lib/kube/shared/app.yml
# app_name = "myapp"
# app_env = "production"

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
          envFrom:
            - secretRef:
                name: $DOPPLER_MANAGED_SECRET_NAME # << name of the secret provided by workflow
```

**Live Reload**

- The integration also supports reloading dependent deployments whenever configuration is updated on Doppler.
- Simply add `annotations.secrets.doppler.com/reload` with value `true` to enable this.
- See [Automatic Redeployments](https://docs.doppler.com/docs/kubernetes-operator#automatic-redeployments) for more info.

### Reference

Here's the complete reference of input/output supported by the workflow:

**Inputs**

| Name                  | Type   | Description                                                                                                                                                            | Required | Default                   |
|-----------------------|--------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|---------------------------|
| app_name              | input  | Application name based on which docker repository, doppler project and kube namespace would be selected                                                                | Yes      | -                         |
| app_env               | input  | Application environment based on which doppler configuration, kube namespace and kube spec files would be selected                                                     | Yes      | -                         |
| app_hostname          | input  | Application hostname where application would be deployed. Available placeholders - {0} Provided application environment, {1} Branch ID generated from provided branch. | Yes      | -                         |
| branch                | input  | Branch from which this workflow was run                                                                                                                                | Yes      | -                         |
| analyze_base          | input  | Base branch against with sonarqube will run code analysis                                                                                                              | No       | -                         |
| aws_cluster_name      | input  | Kubernetes cluster name if deploying on EKS                                                                                                                            | No       | -                         |
| aws_region            | input  | Kubernetes cluster region if deploying on EKS                                                                                                                          | No       | `us-east-1`               |
| aws_use_ecr           | input  | Whether or not ECR login is required. If enabled, provided AWS credentials will be used to authenticating with docker registry.                                        | No       | `false`                   |
| build_args            | input  | Build arguments provided to the docker daemon when building docker image                                                                                               | No       | -                         |
| build_context         | input  | Build context to use with docker. Default to checked out Git directory.                                                                                                | No       | `.`                       |
| checks                | input  | Checks to run. Provide here list of checks in scheme:input format where scheme can be - npm, compose.                                                                  | No       | -                         |
| deploy_root           | input  | Directory where deployment would look for kubernetes specification files                                                                                               | No       | `lib/kube`                |
| deploy_annotate_pr    | input  | Enable pull request annotation with deployment URL. Requires pull_request_number to work.                                                                              | No       | `true`                    |
| docker_registry       | input  | Docker registry where built images will be pushed. By default uses Docker Hub.                                                                                         | No       | `registry.hub.docker.com` |
| docker_username       | input  | Username for authenticating with provided Docker registry                                                                                                              | No       | -                         |
| do_cluster_id         | input  | Kubernetes cluster ID on DigitalOcean if deploying on DOKS                                                                                                             | No       | -                         |
| pull_request_number   | input  | Pull request number running the workflow against a pull request                                                                                                        | No       | -                         |
| aws_access_key_id     | secret | Access key ID for AWS if deploying on EKS                                                                                                                              | No       | -                         |
| aws_secret_access_key | secret | Access key Secret for AWS if deploying on EKS                                                                                                                          | No       | -                         |
| build_secrets         | secret | Build secrets provided to the docker daemon when building docker image                                                                                                 | No       | -                         |
| docker_password       | secret | Password for authenticating with provided Docker registry                                                                                                              | No       | -                         |
| do_access_token       | secret | DigitalOcean access token if deploying on DOKS                                                                                                                         | No       | -                         |
| doppler_token         | secret | Doppler token for accessing environment variables                                                                                                                      | No       | -                         |
| sonar_token           | secret | Authentication token for SonarQube                                                                                                                                     | No       | -                         |

**Outputs**

| Name       | Description                        | Example                        |
|------------|------------------------------------|--------------------------------|
| deploy_url | URL where application was deployed | `https://production.myapp.com` |

## Clean

`.github/workflows/clean.yml` - This is the cleanup workflow which takes care of cleaning up resources. This workflow is typically useful for cleaning up short-lived environments.
See [Running on Branches and PullRequest](#running-on-branches-and-pullrequest) for setup instructions.

**How this works?**

- The cleanup workflow basically runs `kubectl delete` against resources found in the `deploy_root/shared` and `deploy_root/app_env` directories.
- The resources are matched against the `name`, so it's important to follow the naming convention including the Branch ID as defined in [Running on Branches and PullRequest](#running-on-branches-and-pullrequest).

### Cleaning up on DigitalOcean

```yaml
# .github/workflows/clean.yml
# this workflow takes care of cleaning up resources upon PR merge
# the cleanup workflow makes sure to only remove resources associated by the branch

name: clean

on:
  pull_request:
    types: [ closed ]

jobs:
  clean:
    uses: jalantechnologies/github-ci/.github/workflows/clean.yml@v2.5
    with:
      app_name: myapp
      app_env: preview
      branch: ${{ github.event.pull_request.head.ref }}
      docker_registry: 'registry.hub.docker.com'
      docker_username: '<docker_username>'
      do_cluster_id: '<digital_ocean_cluster_id>'
    secrets:
      docker_password: '<docker_password>'
      do_access_token: '<digital_ocean_access_token'
```

```yaml
# lib/kube/shared/app.yml
# notice name - it follows the convention of using KUBE_APP which includes Branch ID

apiVersion: apps/v1
kind: Deployment
metadata:
  name: $KUBE_APP-deployment
  namespace: $KUBE_NS
  labels:
    app: $KUBE_APP
spec:
#  ...
```

```yaml
# lib/kube/preview/app.yml
# same resource following the same convention but in different app_env specific directory
# this will get deleted as well if app_env = preview

apiVersion: apps/v1
kind: Deployment
metadata:
  name: $KUBE_APP-deployment
  namespace: $KUBE_NS
  labels:
    app: $KUBE_APP
spec:
#  ...
```

### Cleaning up on AWS

```yaml
# .github/workflows/clean.yml

name: clean

on:
  pull_request:
    types: [ closed ]

permissions:
  contents: read
  pull-requests: write

jobs:
  clean:
    uses: jalantechnologies/github-ci/.github/workflows/clean.yml@v2.5
    with:
      app_name: myapp
      app_env: preview
      aws_cluster_name: '<aws_cluster_name>'
      aws_region: '<aws_region>'
      branch: ${{ github.event.ref }}
    secrets:
      aws_access_key_id: '<aws_access_key_id>'
      aws_secret_access_key: '<aws_access_secret_key>'
```

### Adding Hooks

- Workflow supports running bash scripts as hooks during cleanup lifecycle.
- Hooks can be defined under `scripts` directory residing within `deploy_root` parameter (So for example, if `deploy_root` = `lib/kube`, workflow will look for hooks under `lib/kube/scripts` directory).
- If the hook fails with non 0 error code, it will fail the workflow run.
- The bash scripts along with the Kubernetes specifications have same variables available for usage, see the list _Placeholders_ below.

**Available Hooks**

- `pre-clean.sh` - Hook to be run before any Kubernetes resources are deleted.
- `post-clean.sh` - Hook to be run after all Kubernetes resources have been deleted.

**Example**

```shell
#!/bin/bash
# lib/kube/scripts/post-clean.sh
# this script deletes a custom resource

kubectl delete pvc mycustompvc -n "$KUBE_NS"
```

**Placeholders**

Following placeholders are available for use within scripts and Kubernetes specifications:

| Key       | Description                                                                                                                                     | Example                            |
|-----------|-------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------|
| KUBE_ROOT | Value for `deploy_root` input.                                                                                                                  | `lib/kube`                         |
| KUBE_NS   | Combination of `app_name` and `app_env` inputs.                                                                                                 | `myapp-production`                 |
| KUBE_APP  | Combination of `app_name` and `app_env` inputs with branch ID. See [Running on Branches and PullRequest](#running-on-branches-and-pullrequest). | `myapp-production-6905caad90e785f` |
| KUBE_ENV  | Value for `app_env` input.                                                                                                                      | `production`                       |

### Reference

Here's the complete reference of input/output supported by the workflow:

**Inputs**

| Name                  | Type   | Description                                                                                 | Required | Default                   |
|-----------------------|--------|---------------------------------------------------------------------------------------------|----------|---------------------------|
| app_name              | input  | Application name based on which docker repository and kube namespace would be selected      | Yes      | -                         |
| app_env               | input  | Application environment based on which kube namespace and kube spec files would be selected | Yes      | -                         |
| branch                | input  | Branch from which this workflow was run                                                     | Yes      | -                         |
| aws_cluster_name      | input  | Kubernetes cluster name if deploying on EKS                                                 | No       | -                         |
| aws_region            | input  | Kubernetes cluster region if deploying on EKS                                               | No       | `us-east-1`               |
| deploy_root           | input  | Directory where deployment would look for kubernetes specification files                    | No       | `lib/kube`                |
| docker_registry       | input  | Docker registry where built images were pushed. By default uses Docker Hub.                 | No       | `registry.hub.docker.com` |
| docker_username       | input  | Username for authenticating with provided Docker registry                                   | No       | -                         |
| do_cluster_id         | input  | Kubernetes cluster ID on DigitalOcean if deploying on DOKS                                  | No       | -                         |
| aws_access_key_id     | secret | Access key ID for AWS if deploying on EKS                                                   | No       | -                         |
| aws_secret_access_key | secret | Access key Secret for AWS if deploying on EKS                                               | No       | -                         |
| docker_password       | secret | Password for authenticating with provided Docker registry                                   | No       | -                         |
| do_access_token       | secret | DigitalOcean access token if deploying on DOKS                                              | No       | -                         |

**Outputs**

This workflow does not have any outputs
