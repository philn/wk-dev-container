#!/bin/sh

NAME=$1
VERSION=$2

LIB_DIR="/usr/lib64/"

wget https://static.crates.io/crates/gst-plugin-$NAME/gst-plugin-$NAME-$VERSION.crate
tar xf gst-plugin-$NAME-$VERSION.crate
pushd gst-plugin-$NAME-$VERSION
cargo cinstall --release --prefix=/usr --libdir=$LIB_DIR
popd
rm -fr gst-plugin-$NAME-$VERSION gst-plugin-$NAME-$VERSION.crate
rm -f $LIB_DIR/gstreamer-1.0/*.a
