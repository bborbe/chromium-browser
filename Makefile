DOCKER_REGISTRY ?= docker.io
IMAGE           ?= bborbe/chromium-browser
PLATFORM        ?= linux/amd64
ifeq ($(VERSION),)
	VERSION := $(shell git describe --tags `git rev-list --tags --max-count=1` 2>/dev/null)
endif

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
build: check-version-tag
	docker build --pull --platform=$(PLATFORM) -t $(DOCKER_REGISTRY)/$(IMAGE):$(VERSION) -f Dockerfile .

upload:
	docker push $(DOCKER_REGISTRY)/$(IMAGE):$(VERSION)

buca: build upload

run:
	docker run -ti -p 9222:9222 $(DOCKER_REGISTRY)/$(IMAGE):$(VERSION)
