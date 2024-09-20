
tag := "wk-dev:f40"
default_image := "ghcr.io/philn"
default_archive := "wk-dev-container.tar"

build:
  podman pull registry.fedoraproject.org/fedora-toolbox:40
  podman build -t {{tag}} .

push image=default_image:
  podman push {{tag}} {{image}}/{{tag}}

pull image=default_image:
  podman pull {{image}}/{{tag}}
  ./wk-bx -u --image {{image}}
  podman image prune -a -f

export archive=default_archive: build
  podman save --format=oci-archive -o {{archive}} {{tag}}

import archive=default_archive:
  podman load < {{archive}}
