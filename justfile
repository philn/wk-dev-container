
tag := "wk-dev:f40"
default_registry := "docker://philn2"
default_image := "docker.io/philn2"
default_archive := "wk-dev-container.tar"

build:
  podman pull registry.fedoraproject.org/fedora-toolbox:40
  podman build -t {{tag}} .

push registry=default_registry:
  podman push {{tag}} {{registry}}/{{tag}}

pull image=default_image:
  podman pull {{image}}/{{tag}}
  ./wk-bx -u --image {{image}}

export archive=default_archive: build
  podman save --format=oci-archive -o {{archive}} {{tag}}

import archive=default_archive:
  podman load < {{archive}}
