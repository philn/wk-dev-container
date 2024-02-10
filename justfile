
tag := "wk-dev:f39"
registry := "docker://philn2"

build:
  podman build -t {{tag}} .

push: build
  podman push {{tag}} {{registry}}/{{tag}}
