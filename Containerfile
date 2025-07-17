FROM registry.fedoraproject.org/fedora-toolbox:42

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/clangd-indexer/bin:/usr/local/clangd/bin:$PATH \
    DEBUGINFOD_URLS=https://debuginfod.fedoraproject.org \
    QT_QPA_PLATFORM=wayland

ENV WEBKIT_ENABLE_DEBUG_PERMISSIONS_IN_SANDBOX=1

# Add rpm fusion repositories in order to access all of the gst plugins
RUN dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# libwpe/wpebackend-fdo are not packaged in Fedora anymore.
RUN dnf copr enable -y philn/wpewebkit

# Remove useless vlc stuff
RUN dnf -y remove vlc-libs

COPY packages/ /packages/
RUN dnf -y install $(<packages/build-deps)
RUN dnf -y install $(<packages/multimedia-deps)
RUN dnf -y install $(<packages/tools)

RUN dnf -y remove mesa-va-drivers
RUN dnf -y install mesa-va-drivers-freeworld

RUN pip install meson

RUN ln -s /usr/bin/flatpak-xdg-open /usr/bin/xdg-open

RUN dnf -y builddep gstreamer1-plugins-bad-free

RUN git config --global user.email "philn@igalia.com"
RUN git config --global user.name "Philippe Normand"

# Rust required for gst-ptp-helper and dots-viewer.
ARG RUSTUP_VERSION=1.28.2
ARG RUST_VERSION=1.88.0
ARG RUST_ARCH="x86_64-unknown-linux-gnu"
ARG RUSTUP_URL=https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$RUST_ARCH/rustup-init
RUN wget $RUSTUP_URL && \
    chmod +x rustup-init && \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION && \
    rm rustup-init && \
    source "$CARGO_HOME/env"

RUN cargo install cargo-c

RUN git clone https://github.com/ystreet/librice.git && \
    pushd librice && \
    cargo cinstall -p librice-proto --release --prefix=/usr --libdir=/usr/lib64 --library-type=cdylib && \
    cargo cinstall -p librice-io --release --prefix=/usr --libdir=/usr/lib64 --library-type=cdylib && \
    popd && \
    rm -fr librice

# NOTE: gupnp is disabled in libnice, triggers critical warnings and leaks.
RUN git clone -b 1.26 https://gitlab.freedesktop.org/gstreamer/gstreamer && \
    git -C gstreamer checkout 1.26.4 && \
    meson setup --prefix=/usr \
       -Dpackage-origin=wk-dev-container \
       -Ddoc=disabled \
       -Dtests=disabled \
       -Dges=disabled \
       -Drtsp_server=disabled \
       -Dgst-examples=disabled \
       -Dpython=disabled \
       -Dgpl=enabled \
       -Dgst-plugins-bad:amfcodec=disabled \
       -Dgst-plugins-bad:avtp=disabled \
       -Dgst-plugins-bad:dc1394=disabled \
       -Dgst-plugins-bad:directfb=disabled \
       -Dgst-plugins-bad:directshow=disabled \
       -Dgst-plugins-bad:dts=disabled \
       -Dgst-plugins-bad:dvbsuboverlay=disabled \
       -Dgst-plugins-bad:dvdspu=disabled \
       -Dgst-plugins-bad:faac=disabled \
       -Dgst-plugins-bad:faad=disabled \
       -Dgst-plugins-bad:flite=disabled \
       -Dgst-plugins-bad:gpl=enabled \
       -Dgst-plugins-bad:gs=disabled \
       -Dgst-plugins-bad:iqa=disabled \
       -Dgst-plugins-bad:libde265=disabled \
       -Dgst-plugins-bad:magicleap=disabled \
       -Dgst-plugins-bad:mpeg2enc=disabled \
       -Dgst-plugins-bad:mplex=disabled \
       -Dgst-plugins-bad:msdk=disabled \
       -Dgst-plugins-bad:neon=disabled \
       -Dgst-plugins-bad:onnx=disabled \
       -Dgst-plugins-bad:openaptx=disabled \
       -Dgst-plugins-bad:opencv=disabled \
       -Dgst-plugins-bad:openni2=disabled \
       -Dgst-plugins-bad:opensles=disabled \
       -Dgst-plugins-bad:qsv=disabled \
       -Dgst-plugins-bad:rtmp=disabled \
       -Dgst-plugins-bad:sbc=disabled \
       -Dgst-plugins-bad:siren=disabled \
       -Dgst-plugins-bad:tinyalsa=disabled \
       -Dgst-plugins-bad:voaacenc=disabled \
       -Dgst-plugins-bad:wasapi2=disabled \
       -Dgst-plugins-bad:wasapi=disabled \
       -Dgst-plugins-bad:wpe=disabled \
       -Dgst-plugins-bad:x11=disabled \
       -Dgst-plugins-bad:zxing=disabled \
       -Dgst-plugins-ugly:gpl=enabled \
       -Dlibnice:gupnp=disabled \
     _build gstreamer/ && \
    meson compile -C _build && \
    meson install -C _build && \
    rm -fr _build gstreamer

RUN git clone https://github.com/rr-debugger/rr && \
    cmake -GNinja -B rr-build -S rr -DCMAKE_INSTALL_PREFIX=/usr -Ddisable32bit=ON -DBUILD_TESTS=OFF && \
    ninja -C rr-build install && \
    rm -fr rr-build rr

RUN git clone https://github.com/ggerganov/whisper.cpp && \
    cmake -GNinja -B whisper-build -S whisper.cpp -DCMAKE_INSTALL_PREFIX=/usr -DWHISPER_BUILD_TESTS=NO -DWHISPER_BUILD_EXAMPLES=NO -DWHISPER_BUILD_SERVER=NO && \
    ninja -C whisper-build install && \
    rm -fr whisper-build whisper.cpp

RUN git clone http://github.com/project-spiel/libspiel && \
    meson setup --prefix=/usr -Dtests=false _build libspiel && \
    meson compile -C _build && \
    meson install -C _build && \
    rm -fr _build libspiel

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

RUN pip install pandas plotly kaleido

RUN git clone https://github.com/webkitgtk/webkitgtk-test-dicts && \
    make -C webkitgtk-test-dicts DESTDIR=/usr/share install && \
    rm -fr webkitgtk-test-dicts

COPY scripts/ /scripts/

RUN cargo install flamegraph
RUN cargo install --locked samply

RUN /scripts/install-gst-plugins-rs.sh audiofx 0.14.0
RUN /scripts/install-gst-plugins-rs.sh closedcaption 0.14.0
RUN /scripts/install-gst-plugins-rs.sh rtp 0.14.0
RUN /scripts/install-gst-plugins-rs.sh dav1d 0.14.0
RUN /scripts/install-gst-plugins-rs.sh fmp4 0.14.0
RUN /scripts/install-gst-plugins-rs.sh tracers 0.14.0

RUN cargo install sccache@0.10.0
RUN /scripts/prepare-sccache.sh

RUN /scripts/install-build-webkit.sh
RUN /scripts/install-launchers.sh

ARG CLANGD_TOOLS_VERSION=20.1.8
RUN wget https://github.com/clangd/clangd/releases/download/$CLANGD_TOOLS_VERSION/clangd_indexing_tools-linux-$CLANGD_TOOLS_VERSION.zip && \
    unzip clangd_indexing_tools-linux-$CLANGD_TOOLS_VERSION.zip && \
    mkdir -p /usr/local/clangd-indexer && \
    mv clangd_$CLANGD_TOOLS_VERSION/* /usr/local/clangd-indexer && \
    rm -fr clangd_indexing_tools-linux-$CLANGD_TOOLS_VERSION.zip

RUN wget https://github.com/clangd/clangd/releases/download/$CLANGD_TOOLS_VERSION/clangd-linux-$CLANGD_TOOLS_VERSION.zip && \
    unzip clangd-linux-$CLANGD_TOOLS_VERSION.zip && \
    mkdir -p /usr/local/clangd && \
    mv clangd_$CLANGD_TOOLS_VERSION/* /usr/local/clangd && \
    rm -fr clangd-linux-$CLANGD_TOOLS_VERSION.zip

RUN dnf clean all
RUN rm -rf /var/cache/dnf /var/log/dnf* /scripts/ /patches/ /packages /clang*
RUN rm -f /var/lib/dnf/history.*
