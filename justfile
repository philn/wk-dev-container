
tag := "wk-dev:f39"
registry := "docker://philn2"
image := "docker.io/philn2"

build:
  podman build -t {{tag}} .

push: build
  podman push {{tag}} {{registry}}/{{tag}}

pull:
  podman pull {{image}}/{{tag}}
  ./wk-bx -u --image {{image}}
