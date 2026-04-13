#!/bin/sh

ARCH=`uname -m`
if [[ "$ARCH" != "x86_64" ]]; then
    exit 0
fi

dnf -y install libva-intel-driver
