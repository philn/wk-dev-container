FROM registry.fedoraproject.org/fedora-toolbox:44

ARG GIT_HASH

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/clangd-indexer/bin:/usr/local/clangd/bin:$PATH \
    DEBUGINFOD_URLS=https://debuginfod.fedoraproject.org \
    QT_QPA_PLATFORM=wayland

ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/host/run/dbus/system_bus_socket
ENV WEBKIT_ENABLE_DEBUG_PERMISSIONS_IN_SANDBOX=1
ENV WEBKIT_BUILD_USE_SYSTEM_LIBRARIES=1
ENV WEBKIT_CONTAINER_SDK=0
ENV WEBKIT_CONTAINER_SDK_INSIDE_MOUNT_NAMESPACE=1

# Add rpm fusion repositories in order to access all of the gst plugins
RUN dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# libwpe/wpebackend-fdo are not packaged in Fedora anymore.
RUN dnf copr enable -y philn/wpewebkit

# Remove useless vlc stuff
RUN dnf -y remove vlc-libs

COPY scripts/ /scripts/

COPY packages/ /packages/
RUN dnf -y install $(<packages/build-deps)
RUN dnf -y install $(<packages/multimedia-deps)
RUN dnf -y install $(<packages/tools)
RUN /scripts/x86-setup.sh

RUN dnf -y swap ffmpeg-free ffmpeg --allowerasing
RUN dnf -y install ffmpeg-devel

RUN pip install meson

RUN ln -s /usr/bin/flatpak-xdg-open /usr/bin/xdg-open

RUN dnf -y builddep gstreamer1-plugins-bad-free

RUN git config --global user.email "philn@igalia.com"
RUN git config --global user.name "Philippe Normand"

# Rust required for gst-ptp-helper and dots-viewer.
ARG RUST_VERSION=1.94.0
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --component rust-src && \
    source "$CARGO_HOME/env"

ARG RUST_ANALYZER_VERSION=2026-01-12
RUN curl -L https://github.com/rust-lang/rust-analyzer/releases/download/$RUST_ANALYZER_VERSION/rust-analyzer-$(rustc -vV | awk '/^host/ { print $2 }').gz | gunzip -c - > /usr/local/bin/rust-analyzer && \
    chmod +x /usr/local/bin/rust-analyzer

RUN cargo install cargo-c

RUN git clone https://github.com/ystreet/librice.git && \
    pushd librice && \
    git checkout v0.3.0 && \
    cargo cinstall -p rice-proto --release --prefix=/usr --libdir=/usr/lib64 --library-type=cdylib && \
    cargo cinstall -p rice-io --release --prefix=/usr --libdir=/usr/lib64 --library-type=cdylib && \
    popd && \
    rm -fr librice

# NOTE: gupnp is disabled in libnice, triggers critical warnings and leaks.
RUN git clone -b 1.28 https://gitlab.freedesktop.org/gstreamer/gstreamer && \
    git -C gstreamer checkout 1.28.1 && \
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
       -Dgst-plugins-bad:wildmidi=disabled \
       -Dgst-plugins-bad:wpe=disabled \
       -Dgst-plugins-bad:x11=disabled \
       -Dgst-plugins-bad:zxing=disabled \
       -Dgst-plugins-ugly:gpl=enabled \
       -Dlibnice:gupnp=disabled \
     _build gstreamer/ && \
    meson compile -C _build && \
    meson install -C _build && \
    rm -fr _build gstreamer

# This is from the host GStreamer version and conflicts with 1.28's.
RUN rm -f /usr/lib64/gstreamer-1.0/libgsty4menc.so

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

RUN /scripts/write-release-infos.sh

RUN cargo install flamegraph
RUN cargo install --locked samply

RUN /scripts/install-gst-plugins-rs.sh audiofx 0.15.0
RUN /scripts/install-gst-plugins-rs.sh closedcaption 0.15.1
RUN /scripts/install-gst-plugins-rs.sh rtp 0.15.1
RUN /scripts/install-gst-plugins-rs.sh dav1d 0.15.0
RUN /scripts/install-gst-plugins-rs.sh isobmff 0.15.0
RUN /scripts/install-gst-plugins-rs.sh tracers 0.15.0

RUN cargo install sccache@0.14.0
RUN /scripts/prepare-sccache.sh

RUN /scripts/install-build-webkit.sh
RUN /scripts/install-launchers.sh

ARG CLANGD_TOOLS_VERSION=22.1.0
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

RUN dnf remove -y proj-data.noarch fluid-soundfont-common.noarch

RUN rm -fr /usr/local/cargo/registry/* && \
    chmod -R a+w /usr/local/cargo/registry/

RUN find /usr/share/locale/* \
    -maxdepth 0 \
    -type d \
    -not -iname "en*" \
    -exec rm -r {} \;

RUN dnf clean all
RUN rm -rf /var/cache/dnf /var/log/dnf* /scripts/ /patches/ /packages /clang*
RUN rm -fr /var/lib/dnf/history.* /root/.cache
