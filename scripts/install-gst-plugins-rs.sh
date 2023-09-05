#!/bin/sh

NAME=$1
VERSION=$2

GST_PLUGINS_DIR="/usr/lib64/gstreamer-1.0"

wget https://static.crates.io/crates/gst-plugin-$NAME/gst-plugin-$NAME-$VERSION.crate
tar xf gst-plugin-$NAME-$VERSION.crate
cargo build --release --manifest-path=gst-plugin-$NAME-$VERSION/Cargo.toml
install -D -m a+r -t $GST_PLUGINS_DIR ./gst-plugin-$NAME-$VERSION/target/release/libgst*.so
rm -fr gst-plugin-$NAME-$VERSION
