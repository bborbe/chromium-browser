DOCKER_REGISTRY ?= docker.io
IMAGE           ?= bborbe/chromium-browser
PLATFORM        ?= linux/amd64
ifeq ($(VERSION),)
	VERSION := $(shell git describe --tags `git rev-list --tags --max-count=1` 2>/dev/null)
endif

# Which machine builds the image. `local` builds here with the local daemon; any
# other value is a cluster alias (sun, nukedev, nukeprod) or a raw kubectl
# context name, and the build runs as a Job there.
# Unset BUILD_TARGET resolves automatically: a bounded `kubectl get --raw /readyz`
# probe through hack/cluster-alias.sh picks sun when it answers and the local
# daemon when it does not. An explicit BUILD_TARGET always wins and the probe is
# never run. SUN_PROBE=fail short-circuits the probe to "unreachable", so the
# fallback can be exercised without touching the cluster:
#   make -n build SUN_PROBE=fail
#
# The probe is cheap where sun is absent: with no sun kubeconfig on the host,
# kubectl fails immediately, so CI pays nothing. It costs the timeout only on a
# machine that holds the kubeconfig but cannot reach the cluster.
BUILD_TARGET_PROBE_TIMEOUT ?= 5
SUN_PROBE ?=

ifeq ($(origin BUILD_TARGET),undefined)
  ifeq ($(SUN_PROBE),fail)
    BUILD_TARGET := local
    BUILD_TARGET_REASON := sun unreachable: SUN_PROBE=fail
  else
    BUILD_TARGET_PROBE_OUT := $(shell BUILD_TARGET=sun bash -c 'source hack/cluster-alias.sh && kc --request-timeout=$(BUILD_TARGET_PROBE_TIMEOUT)s get --raw /readyz' 2>/dev/null | grep -qx ok && echo ok)
    ifeq ($(BUILD_TARGET_PROBE_OUT),ok)
      BUILD_TARGET := sun
      BUILD_TARGET_REASON := probe ok
      # The cluster arm needs a REF and a TAG. Default them so a bare `make build`
      # keeps working on a sun-reachable host: REF to HEAD, TAG to a slash-free
      # scratch tag derived from the branch and the commit. Never the bare branch
      # name -- `hack/build-cluster.sh` rejects a TAG containing `/`, and a cluster
      # build must never overwrite a moving tag such as `:master`.
      REF ?= $(shell git rev-parse HEAD)
      VERSION ?= $(subst /,-,$(BRANCH))-$(shell git rev-parse --short HEAD)
    else
      BUILD_TARGET := local
      BUILD_TARGET_PROBE_ERR := $(shell BUILD_TARGET=sun bash -c 'source hack/cluster-alias.sh && kc --request-timeout=$(BUILD_TARGET_PROBE_TIMEOUT)s get --raw /readyz' 2>&1 >/dev/null | head -1)
      BUILD_TARGET_REASON := sun unreachable: $(if $(BUILD_TARGET_PROBE_ERR),$(BUILD_TARGET_PROBE_ERR),probe failed)
    endif
  endif
  $(info build target: $(BUILD_TARGET) ($(BUILD_TARGET_REASON)))
else
  $(info build target: $(BUILD_TARGET) (explicit))
endif

# Cluster-build inputs. The vendored cluster script defaults the namespace,
# timeout and Dockerfile; the clone URL, tag and image come from this repository.
BUILD_TIMEOUT ?= 3600
BUILD_REPO_URL ?= https://github.com/$(IMAGE).git
BUILD_DOCKERFILE ?= Dockerfile
BUILD_PUSH_SECRET ?= buildkit-push

# The commit the cluster clones. Empty on purpose: the cluster arm must be told
# which commit to build, and the script refuses to run without it.
REF ?=

.PHONY: check-version-tag
check-version-tag:
	@if [ -n "$(ALLOW_UNTAGGED_BUILD)" ]; then \
	  echo "ALLOW_UNTAGGED_BUILD set — skipping version/tag check"; \
	else \
	  head_tag=$$(git describe --tags --exact-match HEAD 2>/dev/null); \
	  if [ "$$head_tag" != "$(VERSION)" ]; then \
	    echo "ERROR: refusing to build $(VERSION) from this tree." >&2; \
	    echo "  HEAD is at tag: $${head_tag:-<untagged>}" >&2; \
	    echo "  building as:    $(VERSION)" >&2; \
	    echo "  An image stamped vX.Y.Z must be built from the vX.Y.Z tag." >&2; \
	    echo "  Fix: git checkout $(VERSION)   (or set ALLOW_UNTAGGED_BUILD=1 for a scratch build)" >&2; \
	    exit 1; \
	  fi; \
	fi

.PHONY: build upload buca run

# Publish-only: build + push docker.io/bborbe/chromium-browser:vX.Y.Z (git-tag semver).
ifeq ($(BUILD_TARGET),local)
build: check-version-tag
	docker build --pull --platform=$(PLATFORM) -t $(DOCKER_REGISTRY)/$(IMAGE):$(VERSION) -f Dockerfile .
else
build:
	@if [ -z "$(REF)" ]; then \
		echo "ERROR: REF is required for a cluster build — pass REF=<commit>" >&2; \
		exit 1; \
	fi
	@if [ "$(origin VERSION)" = "file" ] || [ "$(origin VERSION)" = "undefined" ]; then \
		echo "ERROR: VERSION is not set, and the Makefile default is the latest release tag ($(VERSION))." >&2; \
		echo "  The cluster arm pushes, so building REF=$(REF) would overwrite the published" >&2; \
		echo "  image for that release tag with an image built from a different commit." >&2; \
		echo "  Set it explicitly: make build BUILD_TARGET=$(BUILD_TARGET) REF=$(REF) VERSION=<scratch>" >&2; \
		exit 1; \
	fi
	@case "$(VERSION)" in \
		v[0-9]*.[0-9]*.[0-9]*) \
			if [ "$(REF)" != "$(VERSION)" ]; then \
				echo "ERROR: refusing to push release tag $(VERSION) from REF=$(REF)." >&2; \
				echo "  A release image must be built from its own tag: REF=$(VERSION)." >&2; \
				exit 1; \
			fi ;; \
	esac
	BUILD_TARGET='$(BUILD_TARGET)' \
	NAMESPACE='build' \
	TIMEOUT='$(BUILD_TIMEOUT)' \
	REPO_URL='$(BUILD_REPO_URL)' \
	REF='$(REF)' \
	TAG='$(VERSION)' \
	DOCKERFILE='$(BUILD_DOCKERFILE)' \
	IMAGE='$(DOCKER_REGISTRY)/$(IMAGE)' \
	PUSH='true' \
	PUSH_SECRET='$(BUILD_PUSH_SECRET)' \
	hack/build-cluster.sh
endif

upload:
ifeq ($(BUILD_TARGET),local)
	docker push $(DOCKER_REGISTRY)/$(IMAGE):$(VERSION)
else
	@echo "upload: skipped — BUILD_TARGET=$(BUILD_TARGET); the cluster Job already pushed $(DOCKER_REGISTRY)/$(IMAGE):$(VERSION)"
endif

buca: build upload

run:
	docker run -ti -p 9222:9222 $(DOCKER_REGISTRY)/$(IMAGE):$(VERSION)
