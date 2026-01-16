# Installation

As this image has been pushed to my ghcr, you can download it:

```sh
$ just pull
```

`wk-bx` takes care of (re-)creating the toolbox from the given OCI image.
Optionally it can also prepare a SCCache configuration file, in the runtime
container path `/sccache/` if the `-t token-goes-here` option is passed. If it's
ommitted and there is an older toolbox of the SDK already, the old SCCache auth
credentials will be reused, so you need to use the `-t` option only once, or in
case the credentials on the cluster have changed.

A `clangd` wrapper called `webkit-clangd` is provided by the runtime. If your
IDE runs in flatpak you can wrap it in another script like this (YMMV):

```sh
#!/bin/sh
set -eu
flatpak-spawn --host podman start wk-dev-f43
exec flatpak-spawn --host podman exec -e WEBKIT_HOME=$HOME/WebKit -i -u phil \
     wk-dev-f43 webkit-clangd --enable-config --gtk "$@"
```

Or, for IDEs not running in flatpak:

```sh
#!/bin/sh
set -eu
podman start wk-dev-f43
exec podman exec -e WEBKIT_HOME=$HOME/WebKit -i -u phil \
     wk-dev-f43 webkit-clangd --enable-config --gtk "$@"
```

A similar approach can be used for setting up rust-analyzer:

```sh
#!/bin/sh
set -eu
podman start wk-dev-f43
exec podman exec -i -u phil wk-dev-f43 /usr/local/bin/rust-analyzer "$@"
```

# Local build of the container

If you prefer to build the container yourself:

```sh
$ podman build -t wk-dev:f43 .
$ ./wk-bx -u
```

# Runtime usage

`b-webkit` and `run-minibrowser` are scripts provided by the container.
`WEBKIT_HOME` should point to your WebKit checkout. Can be set in a `.envrc` there for instance.

```sh
toolbox enter -c wk-dev-f43
export WEBKIT_HOME=$HOME/WebKit
cd $WEBKIT_HOME
b-webkit --wpe
run-minibrowser --wpe
```

## Environment variables

- `WEBKIT_HOME`: Path to the WebKit git checkout (required)
- `EXTRA_BUILD_WEBKIT_ARGS`: Additional options for `b-webkit`. Example: `"--cmakeargs=-DENABLE_DOCUMENTATION=OFF --cmakeargs=-DENABLE_INTROSPECTION=OFF --cmakeargs=-DENABLE_COG=ON"` (optional)
- `WEBKIT_USE_SCCACHE`: Set to `1` to enable sccache (requires valid sccache config) (optional)
- `SCCACHE_NUM_CPUS` : Number of CPUs usable in the sccache cluster (optional)
- `SCCACHE_CONF` : Path to sccache config, set this to `/sccache/sccache.toml` if you enabled sccache in the container (optional)
- `WEBKIT_SDK_LOCAL_DEPS` : Comma-separated list of local Meson projects paths to build (optional)
- `WEBKIT_SDK_LOCAL_DEPS_$PROJECT_OPTIONS`: Custom Meson options to pass to the given project identified by its source path basename, converted to upper case (optional)
- `WEBKIT_OUTPUTDIR`: Custom WebKit build output directory (optional)
- `CC`: C compiler, defaults to `gcc` (optional)
- `CXX`: C++ compiler, defaults to `g++` (optional)
