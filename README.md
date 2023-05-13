# GitHub CI

Defines workflows which allows you to run CI checks and deployments using Docker and GitHub Actions. Supports:

- Analysis - Running code analysis using SonarQube
- Checks - Running Functional, E2E, Lint checks (with support for adding your own checks with dependencies using `docker compose`)
- Deployment - Supports deploying on [Digital Ocean's Kubernetes Cluster](https://www.digitalocean.com/products/kubernetes)
- Configuration - Supports [Doppler](https://www.doppler.com) for injecting sensitive configuration values during deployments.

## Demo

Our MERN Boilerplate implements the workflows documented here. Find the project [here](https://github.com/jalantechnologies/boilerplate-mern).

## Development

- Create a new branch for the version (Example - `v1.1`)
- Update the default value for `ci_version` input to the created branch name (Example - `v1.1`)
- Commit new updates
- To test out changes, push the changes and update the workflow ref. Example - `jalantechnologies/github-ci/.github/workflows/ci.yml@v1.1`
- Update `CHANGELOG` and add the new version, listing out the updates that have been done.
- Push new changes and raise PR for review
- `Squash and Merge` new changes once PR is approved
- Workflows can now use this updated workflow using the branch name. Example - `jalantechnologies/github-ci/.github/workflows/ci.yml@v1.1`.
