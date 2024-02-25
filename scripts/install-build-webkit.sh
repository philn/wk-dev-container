#!/bin/sh

PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}')")
PY_DEST="/usr/local/lib/python${PY_VERSION}/site-packages"

BIN_DEST=/usr/local/bin

mkdir -p $PY_DEST
mv /scripts/*.py $PY_DEST

mv /scripts/b-webkit $BIN_DEST
mv /scripts/b-webkits $BIN_DEST
mv /scripts/build-webkit-ng $BIN_DEST
