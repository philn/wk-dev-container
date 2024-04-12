
tag := "wk-dev:f40"
registry := "docker://philn2"
image := "docker.io/philn2"

build:
  podman pull registry.fedoraproject.org/fedora-toolbox:40
  podman build -t {{tag}} .

push: build
  podman push {{tag}} {{registry}}/{{tag}}

pull:
  podman pull {{image}}/{{tag}}
  ./wk-bx -u --image {{image}}
