#!/bin/sh

ARCH=`uname -m`
if [[ "$ARCH" != "x86_64" ]]; then
    exit 0
fi

dnf -y install libva-intel-driver
dnf -y remove mesa-va-drivers
dnf -y install mesa-va-drivers-freeworld
