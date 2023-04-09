# Installation

As this image has been pushed to my dockerhub, you can download it:

```sh
$ ./wk-bx -u --image docker.io/philn2
```

# Local build

If you prefer to build it yourself:

```sh
$ podman build -t wk-dev:f38 .
$ ./wk-bx -u
```
