# GitHub CI

This is a central repository for GitHub actions and workflows for running CI/CD pipeline on GitHub. As of the writing, we support deploying on following deployment services:

- Kubernetes on DigitalOcean
- Render

## Demo

Our MERN Boilerplate implements the workflows documented here. Find the project [here](https://github.com/jalantechnologies/boilerplate-mern).

## Requirements

- Digital Ocean account
- Kubernetes Cluster on Digital Ocean
- Docker repository
- DNS Account
- Doppler (For configuration management - Optional)
- SonarQube (For running code analysis - Optional)

## Account on Digital Ocean

- We will be needing API access token in order to interact with the resources on Digital Ocean
- Learn about to create a personal access token [here](https://docs.digitalocean.com/reference/api/create-personal-access-token/). Token needs to have both `read` and `write` scope.
- Take a note of the created **API token**. We will be needing this for rest of the setup.

## Setting up the Kubernetes Cluster

- Creating Kubernetes cluster via Digital Ocean console
  - Learn about how to set up a Kubernetes cluster on Digital Ocean [here](https://docs.digitalocean.com/products/kubernetes/quickstart/).
  - Take a note of the created **cluster's ID**. We will be needing this for rest of the setup.
- Install `kubectl`
  - Command line tool to interact with the Kubernetes cluster. Learn on how to install it locally [here](https://kubernetes.io/docs/tasks/tools/#kubectl)
  - To check if successfully installed, run - `kubectl version`
- Install `doctl`
  - Command line tool to interact with resources on Digital Ocean. We need this to authenticate our `kubectl` client with our Kubernetes cluster.
  - Learn on how to install it locally [here](https://docs.digitalocean.com/reference/doctl/how-to/install/).
  - After following the process, make sure following runs successfully - `doctl account get`
- Connect to cluster
  - Run - `doctl kubernetes cluster kubeconfig save <cluster_id>`
  - To verify - `kubectl config current-context` should print out `do-<cluster_region>-<cluster_name>`
- Install `helm`
  - Helm is a package manager which allows us to install third-party packages on our Kubernetes cluster.
  - Learn on how to install is locally [here](https://helm.sh/docs/intro/install/)
- Install using `helm` - Nginx Ingress
  - `helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx`
  - `helm repo update`
  - `helm install nginx-ingress ingress-nginx/ingress-nginx --set controller.publishService.enabled=true`
- Install using `helm` - Cert Manager
  - `kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.yaml`
- Get external IP address for your cluster
  - Our cluster is now ready for handling external traffic.
  - To get IP to which DNS entries can be mapped to (A records), run - `kubectl get service nginx-ingress-ingress-nginx-controller -n default`. Note the value in `EXTERNAL-IP` column.

## Setting up Docker repository

- We will be needing a docker repository where images will be pushed from our workflow and pulled in from the cluster for running the applications.
- Workflow supports number of docker registries, to name a few:
  - [Docker Hub](https://hub.docker.com/)
  - [Digital Ocean's Container Registry](https://www.digitalocean.com/products/container-registry)
  - [Amazon Elastic Container Registry](https://aws.amazon.com/ecr/)
- This guide only documents setting up and integrating Docker Hub with the Kubernetes cluster.
- After creating a repository on Docker Hub, take a note of the **repository's name**, **account username**, **account password** (can use an access token as well here for more control)

## Setting up DNS

For routing traffic to your cluster, add an `A` record for the cluster's external IP which was obtained from _Setting up the Kubernetes Cluster_ step.

## Setting up Doppler

- For configuration management and securely providing access to the secrets to application, this setup uses [Doppler](https://www.doppler.com/) which is allows us to inject configuration parameters as environment variables to application runtime.
- As mentioned, this is an optional requirement and is meant only for application which require runtime configuration.
- Learn about creating a doppler project and environments [here](https://docs.doppler.com/docs/create-project)
- Learn about creating a service token in order to access secret associated with an environment [here](https://docs.doppler.com/docs/service-tokens#dashboard-create-service-token)
- Take a note of the **project**, **environment**, and **service token**. We will be needing this for rest of the setup.

## Setting up SonarQube

- This workflow supports running static analyzer on open PRs and base branch using SonarQube
- Learn more about how to import a GitHub repository into SonarQube [here](https://github.com/jalantechnologies/platform-sonarqube#project-import-process---github)
- Using the steps provided in [If using GitHub actions](https://github.com/jalantechnologies/platform-sonarqube#project-import-process---github), take a note of `SONAR_TOKEN` and `SONAR_HOST_URL`
- No need to follow any remaining steps, workflows here will take care of the rest.

## Workflows

This project offers following workflows which applications can integrate within their GitHub CI pipeline:

### kube

Main workflow responsible for running CI pipeline.

**Usage:**

```yaml
name: production_on_push

on:
  push:
    branches:
      - main

jobs:
  production:
    uses: jalantechnologies/platform-github/.github/workflows/kube.yml
    with:
      app_name: boilerplate-mern
      app_env: production
      app_hostname: boilerplate-mern.platform.jalantechnologies.com
      branch: ${{ github.event.ref }}
    secrets:
      docker_registry: docker-registry.platform.jalantechnologies.com/boilerplate-mern
      docker_username: ${{ secrets.DOCKER_USERNAME }}
      docker_password: ${{ secrets.DOCKER_PASSWORD }}
      doppler_token: ${{ secrets.DOPPLER_PRODUCTION_TOKEN }}
      do_access_token: ${{ secrets.DO_ACCESS_TOKEN }}
      do_cluster_id: ${{ secrets.DO_CLUSTER_ID }}
      sonar_token: ${{ secrets.SONAR_TOKEN }}
      sonar_host_url: ${{ secrets.SONAR_HOST_URL }}
```

**Parameters:**

| **Parameter**       | **Type** | **Description**                                                                                                                                                         | **Required (Y / N)** | **Type (Plaintext / Secret)** |
|---------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|-------------------------------|
| app_name            | string   | Application name based on which docker repository, doppler project and kube namespace would be selected                                                                 | Y                    | Plaintext                     |
| app_env             | string   | Application environment based on which doppler configuration, kube namespace and kube spec files would be selected                                                      | Y                    | Plaintext                     |
| app_hostname        | string   | Application hostname where application would be deployed. Available placeholders: - {0} Provided application environment - {1} Branch ID generated from provided branch | Y                    | Plaintext                     |
| branch              | string   | Branch from which this workflow was run                                                                                                                                 | Y                    | Plaintext                     |
| branch_base         | string   | If analyze is enabled, this refers to the base branch against with sonarqube will run code analysis                                                                     | If using analyze     | Plaintext                     |
| build_args          | string   | Build arguments provided to the docker daemon when building the image. See - https://github.com/docker/buildx/blob/master/docs/reference/buildx_build.md#build-arg      | N                    | Plaintext                     |
| pull_request_number | number   | Pull request number running the workflow against a pull request                                                                                                         | N                    | Plaintext                     |
| steps               | string   | If provided, only specified steps would be run by the workflow. Value to be provided in CSV format. Can include - analyze, lint, test, deploy.                          | N                    | Plaintext                     |
| docker_registry     | string   | Registry to use for application docker images                                                                                                                           | Y                    | Secret                        |
| docker_username     | string   | Username for authenticating against the provided docker registry                                                                                                        | Y                    | Secret                        |
| docker_password     | string   | Password for authenticating against the provided docker registry                                                                                                        | Y                    | Secret                        |
| do_access_token     | string   | Digital Ocean access token                                                                                                                                              | Y                    | Secret                        |
| do_cluster_id       | string   | Kubernetes cluster Id on Digital Ocean                                                                                                                                  | Y                    | Secret                        |
| doppler_token       | string   | Service token for accessing configuration on Doppler                                                                                                                    | If using doppler     | Secret                        |
| sonar_token         | string   | Sonar token for running analysis                                                                                                                                        | If using analyze     | Secret                        |
| sonar_host_url      | string   | Sonar host URL for running analysis                                                                                                                                     | If using analyze     | Secret                        |

**Steps:**

- `analyze`
  - Runs sonarqube analyzer against checked in code
  - Requires `sonar_token` and `sonar_host_url` parameters to be set
  - Run default branch analyzer if no `pull_request_number` was provided
  - Runs new code branch analyzer if `pull_request_number` was provided

- `lint`
  - Runs `npm run lint`
  - Support for specifying custom command will be added soon.

- `test`
  - Run `docker-compose -f docker-compose.test.yml up --exit-code-from app` if `docker-compose.test.yml` was found
  - Otherwise run `npm test`
  - Support for specifying custom command will be added soon.

- `e2e`
  - Run `docker-compose -f docker-compose.e2e.yml up --exit-code-from app` if `docker-compose.e2e.yml` was found
  - Otherwise run `npm test`
  - Support for specifying custom command will be added soon.

- `deploy`
  - Processes and applies kubernetes configuration
  - Looks at following directories for specifications:
    - `lib/kube/core` - Core specifications. Meant for one time resources.
    - `lib/kube/shared` - Shared specification. Meant for specifications common amongst environments.
    - `lib/kube/$KUBE_ENV` - Environment specific configuration. Uses value for `app_env` parameter for `$KUBE_ENV`.
  - Supplies following variables which can be referenced as `$VARIABLE` which can be used in specifications:
    - [Environment variables](https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables) provided by GitHub.
    - `DOCKER_REGISTRY` - Value provided for `docker_registry` parameter
    - `DOCKER_USERNAME` - Value provided for `docker_username` parameter
    - `DOCKER_PASSWORD` - Value provided for `doppler_token` parameter
    - `DOPPLER_TOKEN_SECRET_NAME` - Kubernetes secret name for doppler token (If using doppler)
    - `DOPPLER_MANAGED_SECRET_NAME` - Kubernetes secret name for doppler which can be referenced in kubernetes specifications (If using doppler)
    - `KUBE_NS` - Kubernetes namespace
    - `KUBE_APP` - Kubernetes application name
    - `KUBE_ENV` - Value provided for `app_env`
    - `KUBE_DEPLOYMENT_IMAGE` - Deployment image
    - `KUBE_INGRESS_HOSTNAME` - Kubernetes ingress hostname
  - This step also supports running script before and after running deployment:
    - `lib/kube/scripts/pre-deploy.sh` - For running a script before deployment
    - `lib/kube/scripts/post-deploy.sh` - For running a script after deployment

### clean

For tearing up deployments. Destroys kubernetes resources found in:

- `lib/kube/shared`
- `lib/kube/$KUBE_ENV` - Uses value for `app_env` parameter for `$KUBE_ENV`.

This step also supports running script before and after running cleanup:

- `lib/kube/scripts/pre-clean.sh` - For running a script before cleanup
- `lib/kube/scripts/post-clean.sh` - For running a script after cleanup

**Usage:**

```yaml
name: clean_on_delete

on: delete

jobs:
  clean:
    # only run when deleting a branch
    if: github.event.ref_type == 'branch'
    uses: jalantechnologies/platform-github/.github/workflows/clean.yml
    with:
      app_name: boilerplate-mern
      app_env: preview
      branch: ${{ github.event.ref }}
    secrets:
      do_access_token: ${{ secrets.DO_ACCESS_TOKEN }}
      do_cluster_id: ${{ secrets.DO_CLUSTER_ID }}
```

**Parameters:**

| **Parameter**   | **Type** | **Description**                                                                             | **Required (Y / N)** | **Type (Plaintext / Secret)** |
|-----------------|----------|---------------------------------------------------------------------------------------------|----------------------|-------------------------------|
| app_name        | string   | Application name based on which kube namespace would be selected                            | Y                    | Plaintext                     |
| app_env         | string   | Application environment based on which kube namespace and kube spec files would be selected | Y                    | Plaintext                     |
| branch          | string   | Branch from which this workflow was run                                                     | Y                    | Plaintext                     |
| do_access_token | string   | Digital Ocean access token                                                                  | Y                    | Secret                        |
| do_cluster_id   | string   | Kubernetes cluster Id on Digital Ocean                                                      | Y                    | Secret                        |

## Development

For releasing a new version:

- Create a new branch for the version (Example - `v2.3`)
- Update the default value for `platform_version` input to the created branch name (Example - `v2.3`)
- Commit new updates
- To test out changes, push the changes and update the workflow ref. Example - `jalantechnologies/platform-github/.github/workflows/kube.yml@v2.3`
- Update `CHANGELOG` and add the new version, listing out the updates that have been done.
- Push new changes and raise PR for review
- `Squash and Merge` new changes once PR is approved
- Workflows can now use this updated workflow using the branch name. Example - `jalantechnologies/platform-github/.github/workflows/kube.yml@v2.3`. See [Workflows](#workflows) for usage.
