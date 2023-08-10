# GitHub CI

Defines workflows which allows you to run CI checks and deployments using Docker and GitHub Actions. Supports:

- Analysis - Running code analysis using SonarQube
- Checks - Running Functional, E2E, Lint checks (with support for adding your own checks with dependencies using `docker compose`)
- Deployment - Supports deploying on [Digital Ocean's Kubernetes Cluster](https://www.digitalocean.com/products/kubernetes)
- Configuration - Supports [Doppler](https://www.doppler.com) for injecting sensitive configuration values during deployments.

## Demo

Our MERN Boilerplate implements the workflows documented here. Find the project [here](https://github.com/jalantechnologies/boilerplate-mern).

## Development

- Take latest pull from base branch - `main`
- Create a new branch for the fix / feature, eg - `fix/remove_ci_version_from_clean`
- To test out changes, push the changes and update the workflow ref. Example - `jalantechnologies/github-ci/.github/workflows/ci.yml@fix/remove_ci_version_from_clean`
- Once changes have been tested, getting approval from code owners, PR can be merged using `Squash and Merge`.

## Release

- Create a new branch from `main` from where release needs to happen.
- Follow [semantic versioning](https://docs.npmjs.com/about-semantic-versioning) for creating a new release, eg - `v1.2`
- Update CHANGELOG with changes being released, commit the change.
- Push the branch to origin.
- Raise a PR pointed towards `main` for release. Ask for review from code owners and get it merged.
- Create a new release with title being the version, eg - `v1.2` and description being the items added in CHANGELOG.
- Workflows can now use this new version, eg - `jalantechnologies/github-ci/.github/workflows/ci.yml@v1.2`
