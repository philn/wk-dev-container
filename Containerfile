FROM registry.fedoraproject.org/fedora-toolbox:38

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    DEBUGINFOD_URLS=https://debuginfod.fedoraproject.org \
    QT_QPA_PLATFORM=wayland

# Add rpm fusion repositories in order to access all of the gst plugins
RUN dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

COPY packages/ /packages/
RUN dnf -y install $(<packages/build-deps)
RUN dnf -y install $(<packages/tools)

RUN dnf -y remove mesa-va-drivers
RUN dnf -y install mesa-va-drivers-freeworld

RUN wget https://github.com/rr-debugger/rr/releases/download/5.6.0/rr-5.6.0-Linux-$(uname -m).rpm && \
    dnf -y install rr-5.6.0-Linux-$(uname -m).rpm && \
    rm -f rr-5.6.0-Linux-$(uname -m).rpm

RUN pip3 install meson

RUN git clone http://github.com/Sparkle-CDM/sparkle-cdm && \
    meson setup --prefix=/usr -Dsample-player=disabled _build sparkle-cdm && \
    meson compile -C _build && \
    meson install -C _build && \
    rm -fr _build sparkle-cdm

ARG RUSTUP_VERSION=1.25.1
ARG RUST_VERSION=1.68.0
ARG RUST_ARCH="x86_64-unknown-linux-gnu"
ARG RUSTUP_URL=https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$RUST_ARCH/rustup-init
RUN wget $RUSTUP_URL && \
    chmod +x rustup-init && \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION && \
    rm rustup-init && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME && \
    source "$CARGO_HOME/env"

RUN cargo install sccache@0.3.0

ARG GST_PLUGINS_RS_VERSION=0.9.0
ARG GST_PLUGINS_DIR="/usr/lib64/gstreamer-1.0"
RUN wget https://static.crates.io/crates/gst-plugin-rtp/gst-plugin-rtp-$GST_PLUGINS_RS_VERSION.crate && \
    tar xf gst-plugin-rtp-$GST_PLUGINS_RS_VERSION.crate && \
    cargo build --release --manifest-path=gst-plugin-rtp-$GST_PLUGINS_RS_VERSION/Cargo.toml && \
    install -D -m a+r -t $GST_PLUGINS_DIR ./gst-plugin-rtp-$GST_PLUGINS_RS_VERSION/target/release/libgst*.so && \
    rm -fr gst-plugin-rtp-$GST_PLUGINS_RS_VERSION

RUN wget https://static.crates.io/crates/gst-plugin-closedcaption/gst-plugin-closedcaption-$GST_PLUGINS_RS_VERSION.crate && \
    tar xf gst-plugin-closedcaption-$GST_PLUGINS_RS_VERSION.crate && \
    cargo build --release --manifest-path=gst-plugin-closedcaption-$GST_PLUGINS_RS_VERSION/Cargo.toml && \
    install -D -m a+r -t $GST_PLUGINS_DIR ./gst-plugin-closedcaption-$GST_PLUGINS_RS_VERSION/target/release/libgst*.so && \
    rm -fr gst-plugin-closedcaption-$GST_PLUGINS_RS_VERSION

RUN wget https://static.crates.io/crates/gst-plugin-dav1d/gst-plugin-dav1d-$GST_PLUGINS_RS_VERSION.crate && \
    tar xf gst-plugin-dav1d-$GST_PLUGINS_RS_VERSION.crate && \
    cargo build --release --manifest-path=gst-plugin-dav1d-$GST_PLUGINS_RS_VERSION/Cargo.toml && \
    install -D -m a+r -t $GST_PLUGINS_DIR ./gst-plugin-dav1d-$GST_PLUGINS_RS_VERSION/target/release/libgst*.so && \
    rm -fr gst-plugin-dav1d-$GST_PLUGINS_RS_VERSION

RUN git clone https://github.com/webkitgtk/webkitgtk-test-fonts && \
    make -C webkitgtk-test-fonts DESTDIR=/usr/share install && \
    rm -fr webkitgtk-test-fonts

RUN git clone https://github.com/webkitgtk/webkitgtk-test-dicts && \
    make -C webkitgtk-test-dicts DESTDIR=/usr/share install && \
    rm -fr webkitgtk-test-dicts

COPY scripts/ /scripts/

RUN /scripts/prepare-sccache.sh
RUN /scripts/install-build-webkit.sh

RUN /scripts/install-launchers.sh

RUN dnf clean all
RUN rm -rf /var/cache/dnf /var/log/dnf* /scripts/
RUN rm -f /var/lib/dnf/history.*
