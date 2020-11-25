## PREREQUISITES:
##
## The following variables need to be defined where this file is included:
##   - name
##
## The following files need to be included where this file is included:
##   - common.mk
##


## MACROS
##

# Computes a semantic version from the latest git tag
# Read more: https://semver.org
define compute_semver
	git_status = $(shell git status --porcelain)
	git_describe = $(shell git describe --tags 2> /dev/null)

	# No git tag and no previous semantic version --> using the default initial semantic version
	ifndef git_describe
		commit_count = $$(shell git rev-list --count HEAD)
		git_sha = $$(shell git rev-parse --short HEAD)

		ifdef git_status
			$(1) := 0.1.0-$$(commit_count).dev
		else
			$(1) := 0.1.0-$$(commit_count).$$(git_sha)
		endif
	endif

	# The tag refers to HEAD commit --> current semantic version
	# Example: v0.2.7
	release = $(shell echo $(git_describe) | grep -E -o '^v[0-9]+\.[0-9]+\.[0-9]+$$')
	ifdef release
		semver = $$(shell echo $$(release) | grep -E -o '[0-9]+\.[0-9]+\.[0-9]+')
		major = $$(shell echo $$(semver) | cut -d '.' -f 1)
		minor = $$(shell echo $$(semver) | cut -d '.' -f 2)
		patch = $$(shell echo $$(semver) | cut -d '.' -f 3)

		ifdef git_status
			$(1) := $$(major).$$(minor).$$$$(( $$(patch) + 1 ))-0.dev
		else
			$(1) := $$(major).$$(minor).$$(patch)
		endif
	endif

	# The tag refers to a previous commit --> next semantic version + pre-release version
	# Example: v0.2.7-10-gabcdef
	prerelease = $(shell echo $(git_describe) | grep -E -o '^v[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-g[0-9a-f]+$$')
	ifdef prerelease
		semver = $$(shell echo $$(prerelease) | grep -E -o '[0-9]+\.[0-9]+\.[0-9]+')
		major = $$(shell echo $$(semver) | cut -d '.' -f 1)
		minor = $$(shell echo $$(semver) | cut -d '.' -f 2)
		patch = $$(shell echo $$(semver) | cut -d '.' -f 3)
		commit_count = $$(shell echo $$(prerelease) | cut -d '-' -f 2)
		git_sha = $$(shell git rev-parse --short HEAD)

		ifdef git_status
			$(1) := $$(major).$$(minor).$$$$(( $$(patch) + 1 ))-$$(commit_count).dev
		else
			$(1) := $$(major).$$(minor).$$$$(( $$(patch) + 1 ))-$$(commit_count).$$(git_sha)
		endif
	endif
endef

# Compiles a binary for a target platform
define cross_compile
	GOOS=$(shell echo $(1) | cut -d '-' -f 1) \
	GOARCH=$(shell echo $(1) | cut -d '-' -f 2) \
	go build -ldflags $(ldflags) -o $(build_dir)/$(name)-$(1)
	$(call echo_green,$(build_dir)/$(name)-$(1));
endef


## VARIABLES
##

build_dir := bin
platforms := linux-386 linux-amd64 linux-arm linux-arm64 darwin-amd64 windows-386 windows-amd64


## BUILD METADATA & FLAGS
##
## Git tags are leveraged for semantic versioning.
## A package named version is expected to exist with the following file inside it:
##
## package version
##
## var (
##   Version   string
##   Commit    string
##   Branch    string
##   GoVersion string
##   BuildTool string
##   BuildTime string
## )
##

$(eval $(call compute_semver,version))
commit := $(shell git rev-parse --short HEAD)
branch := $(shell git rev-parse --abbrev-ref HEAD)
go_version := $(shell go version | grep -E -o '[0-9]+\.[0-9]+\.[0-9]+')
build_tool := github.com/moorara/make
build_time := $(shell date +%Y-%m-%dT%T%z)

version_package := $(shell go list ./... | grep -E 'version$$' | head -n 1)
version_flag := -X $(version_package).Version=$(version)
commit_flag := -X $(version_package).Commit=$(commit)
branch_flag := -X $(version_package).Branch=$(branch)
go_version_flag := -X $(version_package).GoVersion=$(go_version)
build_tool_flag := -X $(version_package).BuildTool=$(build_tool)
build_time_flag := -X $(version_package).BuildTime=$(build_time)
ldflags := '$(version_flag) $(commit_flag) $(branch_flag) $(go_version_flag) $(build_tool_flag) $(build_time_flag)'


## RULES
##

.PHONY: test
test:
	go test -race ./...

.PHONY: test-short
test-short:
	go test -short ./...

.PHONY: test-coverage
test-coverage:
	go test -covermode=atomic -coverprofile=c.out ./...
	go tool cover -html=c.out -o coverage.html

.PHONY: clean-test
clean-test:
	rm -f c.out coverage.html

.PHONY: run
run:
	go run main.go

.PHONY: build
build:
	@ go build -ldflags $(ldflags) -o $(name)
	@ $(call echo_green,$(name))

.PHONY: build-all
build-all:
	@ mkdir -p $(build_dir)
	@ $(foreach platform, $(platforms), $(call cross_compile,$(platform)))

.PHONY: clean-build
clean-build:
	rm -rf $(name) $(build_dir)
