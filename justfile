
arch := `uname -m`
base_tag := "wk-dev"
version := "f43"
tag := base_tag + "-" + arch + ":" + version
default_registry := "ghcr.io/philn"
default_archive := "wk-dev-container.tar"
default_manifest := default_registry + "/" + base_tag + ":" + version

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

pull-images registry=default_registry:
  podman pull {{registry}}/{{base_tag}}-x86_64:{{version}}
  podman pull {{registry}}/{{base_tag}}-aarch64:{{version}}

bundle-images manifest=default_manifest registry=default_registry:
  podman manifest create {{manifest}}
  podman manifest add {{manifest}} containers-storage:{{registry}}/{{base_tag}}-x86_64:{{version}}
  podman manifest add {{manifest}} containers-storage:{{registry}}/{{base_tag}}-aarch64:{{version}}
  podman manifest push --all {{manifest}} docker://{{manifest}}
