FROM registry.fedoraproject.org/fedora-toolbox:39

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    DEBUGINFOD_URLS=https://debuginfod.fedoraproject.org \
    QT_QPA_PLATFORM=wayland

ENV WEBKIT_ENABLE_DEBUG_PERMISSIONS_IN_SANDBOX=1

# Add rpm fusion repositories in order to access all of the gst plugins
RUN dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

COPY packages/ /packages/
RUN dnf -y install $(<packages/build-deps)
RUN dnf -y install $(<packages/multimedia-deps)
RUN dnf -y install $(<packages/tools)
RUN dnf -y install $(<packages/yocto-deps)

RUN dnf -y remove mesa-va-drivers
RUN dnf -y install mesa-va-drivers-freeworld

RUN pip install meson

RUN dnf -y builddep gstreamer1-plugins-bad-free

RUN git clone -b 1.22 https://gitlab.freedesktop.org/gstreamer/gstreamer && \
    meson setup --prefix=/usr \
       -Damfcodec=disabled \
       -Davtp=disabled \
       -Ddc1394=disabled \
       -Ddirectfb=disabled \
       -Ddirectshow=disabled \
       -Ddoc=disabled \
       -Ddts=disabled \
       -Ddvbsuboverlay=disabled \
       -Ddvdspu=disabled \
       -Dfaac=disabled \
       -Dfaad=disabled \
       -Dflite=disabled \
       -Dgpl=enabled \
       -Dgs=disabled \
       -Diqa=disabled \
       -Dlibde265=disabled \
       -Dmagicleap=disabled \
       -Dmpeg2enc=disabled \
       -Dmplex=disabled \
       -Dmsdk=disabled \
       -Dneon=disabled \
       -Donnx=disabled \
       -Dopenaptx=disabled \
       -Dopencv=disabled \
       -Dopenni2=disabled \
       -Dopensles=disabled \
       -Dqsv=disabled \
       -Drtmp=disabled \
       -Dsbc=disabled \
       -Dsiren=disabled \
       -Dtests=disabled \
       -Dtinyalsa=disabled \
       -Dvoaacenc=disabled \
       -Dwasapi2=disabled \
       -Dwasapi=disabled \
       -Dwpe=disabled \
       -Dx11=disabled \
       -Dzxing=disabled \
     _build gstreamer/subprojects/gst-plugins-bad && \
    meson compile -C _build && \
    meson install -C _build && \
    rm -fr _build gstreamer

# Disable gupnp in libnice, triggers critical warnings and leaks.
RUN git clone https://gitlab.freedesktop.org/libnice/libnice && \
    meson setup --prefix=/usr \
    -Dgupnp=disabled \
    -Dgstreamer=enabled \
    _build libnice && \
    meson compile -C _build && \
    meson install -C _build && \
    rm -fr _build libnice

RUN git clone https://github.com/rr-debugger/rr && \
    dnf -y install capnproto{,-devel} && \
    cmake -GNinja -B rr-build -S rr -DCMAKE_INSTALL_PREFIX=/usr -Ddisable32bit=ON -DBUILD_TESTS=OFF && \
    ninja -C rr-build install && \
    rm -fr rr-build rr

RUN git clone http://github.com/Sparkle-CDM/sparkle-cdm && \
    meson setup --prefix=/usr -Dsample-player=disabled _build sparkle-cdm && \
    meson compile -C _build && \
    meson install -C _build && \
    rm -fr _build sparkle-cdm

RUN git clone https://github.com/ianlancetaylor/libbacktrace && \
    pushd libbacktrace && \
    ./configure --enable-shared --prefix=/usr && make && make install && \
    popd && \
    rm -fr libbacktrace

ARG RUSTUP_VERSION=1.25.1
ARG RUST_VERSION=1.70.0
ARG RUST_ARCH="x86_64-unknown-linux-gnu"
ARG RUSTUP_URL=https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$RUST_ARCH/rustup-init
RUN wget $RUSTUP_URL && \
    chmod +x rustup-init && \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION && \
    rm rustup-init && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME && \
    source "$CARGO_HOME/env"

RUN cargo install sccache@0.5.4

RUN git clone https://github.com/webkitgtk/webkitgtk-test-dicts && \
    make -C webkitgtk-test-dicts DESTDIR=/usr/share install && \
    rm -fr webkitgtk-test-dicts

COPY scripts/ /scripts/

RUN /scripts/install-gst-plugins-rs.sh closedcaption 0.11.0
RUN /scripts/install-gst-plugins-rs.sh dav1d 0.11.0
RUN /scripts/install-gst-plugins-rs.sh rtp 0.11.0

RUN /scripts/prepare-sccache.sh
RUN /scripts/install-build-webkit.sh

RUN /scripts/install-launchers.sh

RUN dnf clean all
RUN rm -rf /var/cache/dnf /var/log/dnf* /scripts/
RUN rm -f /var/lib/dnf/history.*
