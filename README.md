# GitHub CI

Set of GitHub action workflow for running end-to-end CI pipeline:
  - Analyzing the code using [SonarQube](https://www.sonarsource.com/products/sonarqube/)
  - Building a docker image (with cache support) and pushing it to configured docker registry.
  - Running arbitrary checks using built image - Example: `test`, `lint`, `e2e`.
  - Injecting configuration using [Doppler](https://www.doppler.com/).
  - And finally, deploy resources on Kubernetes cluster on [DOKS](https://docs.digitalocean.com/products/kubernetes/) and [EKS](https://aws.amazon.com/eks/).

For instructions on usage, please see - [Usage](docs/USAGE.md)

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
  - Update the changelog with the version and updates that are being released.
  - Raise a pull request with the updated changelog and get approval from the code owners before merging it into main.

- From [Releases](https://github.com/jalantechnologies/github-ci/releases), create a new release.
  - For "Choose a tag", enter the version for release (example - `v2.5`). Select "Create a new tag" option.
  - For "Release title", enter the version for release (example - `v2.5`).
  - For "Release notes", select "Generate release notes".
  - Make sure "Set as the latest release" is selected.
  - Select "Publish Release"

- Once release is published, dependent apps can now use the new release.
- Example - `jalantechnologies/github-ci/.github/workflows/ci.yml@v2.4` can now be changed to `jalantechnologies/github-ci/.github/workflows/ci.yml@v2.5`
