#!/bin/sh

mv /scripts/webkit-clangd /usr/local/bin/
mv /scripts/wk-launcher /usr/local/bin/
mv /scripts/wk-shell /usr/local/bin/
ln -s /usr/local/bin/wk-launcher /usr/local/bin/run-minibrowser
ln -s /usr/local/bin/wk-launcher /usr/local/bin/run-webkit-tests
ln -s /usr/local/bin/wk-launcher /usr/local/bin/test-webkitpy
ln -s /usr/local/bin/wk-launcher /usr/local/bin/test-webkitperl
