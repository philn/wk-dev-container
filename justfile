
tag := "wk-dev:f43"
default_registry := "ghcr.io/philn"
default_archive := "wk-dev-container.tar"

build git_hash=`git describe --always`:
  podman pull registry.fedoraproject.org/fedora-toolbox:43
  podman build --squash-all -t {{tag}} --security-opt seccomp=unconfined --build-arg=GIT_HASH={{git_hash}} .

push registry=default_registry:
  podman push {{tag}} {{registry}}/{{tag}}

pull registry=default_registry:
  ./wk-bx -u --image {{registry}}
  podman image prune -a -f

export archive=default_archive: build
  podman save --format=oci-archive -o {{archive}} {{tag}}

import archive=default_archive:
  podman load < {{archive}}
