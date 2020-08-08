# make

This repo is intended to be used for importing and reusing Makefiles in other repositories.
For referencing this repo in other git repositories, you can use [git submodules](https://git-scm.com/docs/git-submodule).

## Quick Start

In your git repository, add this repo as a git submodule:

```
git submodule add https://github.com:moorara/make.git
git submodule init
```

Then, in the root directory of your repo:

  1. Create a `Makefile`
  1. Set required variables
  1. Import `mk` files from `make` subdirectory

```Makefile
# Required for go.mk
name := my-service

# Required for docker.mk
docker_image := username/my-service
docker_tag := latest

# Required for grpc.mk
proto_path := idl
go_out_path := internal/proto

-include make/go.mk
-include make/docker.mk
-include make/grpc.mk
```

For upgrading the _make_ submodule, run:

```
git submodule update --remote
```
