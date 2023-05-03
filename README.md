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

# Usage

`b-webkit` and `run-minibrowser` are scripts provided by the container.
`WEBKIT_HOME` should point to your WebKit checkout. Can be set in a `.envrc` there for instance.

```sh
toolbox enter -c wk-dev-f38
export WEBKIT_HOME=$HOME/WebKit
cd $WEBKIT_HOME
b-webkit --wpe
run-minibrowser --wpe
```
