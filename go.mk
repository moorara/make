## PREREQUISITES:
##
## The following variables need to be defined where this file is included:
##   - name
##


## MACROS
##

# Computes a semantic version from the latest git tag
# Read more: https://semver.org
define compute_semver
	git_describe = $(shell git describe --tags 2> /dev/null)

	# No tag --> initial semantic version + pre-release version
	ifndef git_describe
		$(1) := 0.1.0-$$(shell git rev-parse --short HEAD)
	endif

	# The tag refers to HEAD commit --> current semantic version
	release = $(shell echo $(git_describe) | grep -E -o '^v[0-9]+\.[0-9]+\.[0-9]+$$')
	ifdef release
		semver = $$(shell echo $$(release) | grep -E -o '[0-9]+\.[0-9]+\.[0-9]+')
		$(1) := $$(semver)
	endif

	# The tag refers to a previous commit --> next semantic version + pre-release version
	prerelease = $(shell echo $(git_describe) | grep -E -o '^v[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-[0-9a-g]+$$')
	ifdef prerelease
		semver = $$(shell echo $$(prerelease) | grep -E -o '[0-9]+\.[0-9]+\.[0-9]+')
		major = $$(shell echo $$(semver) | cut -d '.' -f 1)
		minor = $$(shell echo $$(semver) | cut -d '.' -f 2)
		patch = $$(shell echo $$(semver) | cut -d '.' -f 3)
		$(1) := $$(major).$$(minor).$$$$(( $$(patch) + 1 ))-$$(shell git rev-parse --short HEAD)
	endif
endef

# Compiles a binary for a target platform
define cross_compile
	GOOS=$(shell echo $(1) | cut -d '-' -f 1) \
	GOARCH=$(shell echo $(1) | cut -d '-' -f 2) \
	go build $(ldflags) -o $(build_dir)/$(name)-$(1);
endef


## VARIABLES
##

build_dir := bin
platforms := linux-386 linux-amd64 linux-arm linux-arm64 darwin-386 darwin-amd64 windows-386 windows-amd64


## BUILD METADATA & FLAGS
##
## Git tags are leveraged for semantic versioning.
## A package named version is expected to exist with the following file inside it:
##
## package version
##
## var (
##   Version   string
##   Revision  string
##   Branch    string
##   GoVersion string
##   BuildTool string
##   BuildTime string
## )
##

$(eval $(call compute_semver,version))
revision := $(shell git rev-parse --short HEAD)
branch := $(shell git rev-parse --abbrev-ref HEAD)
go_version := $(shell go version | grep -E -o '[0-9]+\.[0-9]+\.[0-9]+')
build_tool := Makefile
build_time := $(shell date +%Y-%m-%dT%T%z)

version_package := $(shell go list ./... | grep -E 'version$$' | head -n 1)
version_flag := -X $(version_package).Version=$(version)
revision_flag := -X $(version_package).Revision=$(revision)
branch_flag := -X $(version_package).Branch=$(branch)
go_version_flag := -X $(version_package).GoVersion=$(go_version)
build_tool_flag := -X $(version_package).BuildTool=$(build_tool)
build_time_flag := -X $(version_package).BuildTime=$(build_time)
ldflags := -ldflags "$(version_flag) $(revision_flag) $(branch_flag) $(go_version_flag) $(build_tool_flag) $(build_time_flag)"


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
	go build $(ldflags) -o $(name)

.PHONY: build-all
build-all:
	@ mkdir -p $(build_dir)
	$(foreach platform, $(platforms), $(call cross_compile,$(platform)))

.PHONY: clean-build
clean-build:
	rm -rf $(name) $(build_dir)
