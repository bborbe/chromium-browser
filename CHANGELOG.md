# Changelog

All notable changes to this project will be documented in this file.

Please choose versions by [Semantic Versioning](http://semver.org/).

* MAJOR version when you make incompatible API changes,
* MINOR version when you add functionality in a backwards-compatible manner, and
* PATCH version when you make backwards-compatible bug fixes.

## Unreleased

- chore: restate the do-not-merge contract in the gate workflow

## v0.2.1

- fix: keep the rootless BuildKit build container startable. `allowPrivilegeEscalation: false` and `capabilities.drop: ["ALL"]` on that container stop `rootlesskit` from installing its uid/gid map (`newuidmap: operation not permitted`), so every cluster build died at startup; both are removed and the reason is recorded in `hack/build-job.yaml`. Also hardened the clone path: the token is scoped to its origin host, deleted on the error path as well as the success path, and refused over a non-https URL; `REF` can no longer be read as a git option; and `__CONTEXT__` is listed in the template's token table

## v0.2.0

- feat: build the image on a Kubernetes cluster with `make build BUILD_TARGET=<cluster> REF=<sha> VERSION=<tag>`, keeping the default local arm unchanged. `hack/build-cluster.sh`, `hack/cluster-alias.sh` and `hack/build-job.yaml` are vendored from `bborbe/agent-task-executor`; `check-version-tag` stays a local-arm prerequisite, since it describes the local HEAD rather than the commit the cluster builds

## v0.1.1

- fix: `make build` refuses to stamp a version onto a tree that is not that version's tag (`check-version-tag`, escape hatch `ALLOW_UNTAGGED_BUILD=1`). `VERSION` defaults to the newest tag repo-wide, so an operator-run build from an untagged or older tree silently republishes under the newest tag. The guard compares `git describe --exact-match HEAD` against `$(VERSION)` and exits non-zero on mismatch.

## v0.1.0

- Extract chromium-browser (headless Google Chrome + CDP on :9222) from the trading monorepo (publish-only image)
