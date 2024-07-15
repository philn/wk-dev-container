#!/bin/sh

NAME=$1
VERSION=$2

GST_PLUGINS_DIR="/usr/lib64/gstreamer-1.0"

wget https://static.crates.io/crates/gst-plugin-$NAME/gst-plugin-$NAME-$VERSION.crate
tar xf gst-plugin-$NAME-$VERSION.crate
pushd gst-plugin-$NAME-$VERSION
cargo cinstall --prefix=/usr --libdir=$GST_PLUGINS_DIR
popd
rm -fr gst-plugin-$NAME-$VERSION
