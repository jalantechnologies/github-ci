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

- Get the version for release - Increment the latest version following [semantic versioning](https://docs.npmjs.com/about-semantic-versioning).
  - Get the latest version from [Releases](https://github.com/jalantechnologies/github-ci/releases).
  - If there are breaking changes - Major version needs to be bumped (example - `v2.4` will get bumped to `v3.0`)
  - If there are no breaking changes - Minor version needs to be bumped (example - `v2.4` will get bumped to `v2.5`)

- Update the [CHANGELOG](https://github.com/jalantechnologies/github-ci/blob/main/CHANGELOG)
  - Changelog needs to be updated which tracks the updates that are being made with each release.
  - Update the changelog with the version and updates that are being released. Changes can be pushed directly to `main`.

- From [Releases](https://github.com/jalantechnologies/github-ci/releases), create a new release.
  - For "Choose a tag", enter the version for release (example - `v2.5`). Select "Create a new tag" option.
  - For "Release title", enter the version for release (example - `v2.5`).
  - For "Release notes", select "Generate release notes".
  - Make sure "Set as the latest release" is selected.
  - Select "Publish Release"

- Once release is published, dependent apps can now use the new release.
- Example - `jalantechnologies/github-ci/.github/workflows/ci.yml@v2.4` can now be changed to `jalantechnologies/github-ci/.github/workflows/ci.yml@v2.5`
