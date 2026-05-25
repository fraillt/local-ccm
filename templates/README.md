Templates used to create release artifacts by replacing `REPLACE_VERSION` and `REPLACE_OWNER` placeholders.
- Render them locally with `make render RELEASE_VERSION=<version> REPOSITORY_OWNER=<owner>`
- charts - helm charts that are deployed to ghcr.io as OCI images
- static - static manifests with default values deployed as release artifacts
