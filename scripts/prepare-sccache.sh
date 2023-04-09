#!/bin/sh

mkdir -p /sccache
sccache --package-toolchain /usr/bin/gcc /sccache/gcc-toolchain.tar.gz
sccache --package-toolchain /usr/bin/g++ /sccache/g++-toolchain.tar.gz
sccache --package-toolchain /usr/bin/clang /sccache/clang-toolchain.tar.gz
sccache --package-toolchain /usr/bin/clang++ /sccache/clang++-toolchain.tar.gz

cat << EOF > /sccache/sccache.toml.in
[dist]
scheduler_url = "@@scheduler_url@@"
[[dist.toolchains]]
type = "path_override"
compiler_executable = "/usr/bin/c++"
archive = "/sccache/g++-toolchain.tar.gz"
archive_compiler_executable = "/usr/bin/g++"

[[dist.toolchains]]
type = "path_override"
compiler_executable = "/usr/bin/cc"
archive = "/sccache/gcc-toolchain.tar.gz"
archive_compiler_executable = "/usr/bin/gcc"

[[dist.toolchains]]
type = "path_override"
compiler_executable = "/usr/bin/clang++"
archive = "/sccache/clang++-toolchain.tar.gz"
archive_compiler_executable = "/usr/bin/clang++"

[[dist.toolchains]]
type = "path_override"
compiler_executable = "/usr/bin/clang"
archive = "/sccache/clang-toolchain.tar.gz"
archive_compiler_executable = "/usr/bin/clang"

[dist.auth]
type = "token"
token = "@@auth_token@@"
EOF

chmod -R go+rw /sccache
