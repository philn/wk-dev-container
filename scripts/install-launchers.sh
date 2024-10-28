#!/bin/sh

DEST_BIN=/usr/local/bin

mv /scripts/webkit-clangd $DEST_BIN
mv /scripts/wk-launcher $DEST_BIN
mv /scripts/wk-shell $DEST_BIN
mv /scripts/webkit-clangd-indexer $DEST_BIN
mv /scripts/rewrite-wk-gst-log $DEST_BIN
ln -s /usr/local/bin/wk-launcher $DEST_BIN/run-minibrowser
ln -s /usr/local/bin/wk-launcher $DEST_BIN/run-qt-wpe-minibrowser
ln -s /usr/local/bin/wk-launcher $DEST_BIN/run-webkit-tests
ln -s /usr/local/bin/wk-launcher $DEST_BIN/test-webkitpy
ln -s /usr/local/bin/wk-launcher $DEST_BIN/test-webkitperl

mkdir -p /etc/webkit
mv /scripts/common-local.sh /etc/webkit/
mv /scripts/wk-build-local-deps $DEST_BIN
mv /scripts/wk-run-local-deps $DEST_BIN
mv /scripts/wk-run-tests-local-deps $DEST_BIN
