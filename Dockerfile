# @see https://github.com/rust-lang/docker-rust
FROM alpine:3.15 as builder

# install utilities
RUN apk add --update alpine-sdk cmake clang protoc
RUN apk add --no-cache ca-certificates

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.63.0

RUN set -eux; \
    apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
        x86_64) rustArch='x86_64-unknown-linux-musl'; rustupSha256='bdf022eb7cba403d0285bb62cbc47211f610caec24589a72af70e1e900663be9' ;; \
        aarch64) rustArch='aarch64-unknown-linux-musl'; rustupSha256='89ce657fe41e83186f5a6cdca4e0fd40edab4fd41b0f9161ac6241d49fbdbbbe' ;; \
        *) echo >&2 "unsupported architecture: $apkArch"; exit 1 ;; \
    esac; \
    url="https://static.rust-lang.org/rustup/archive/1.24.3/${rustArch}/rustup-init"; \
    wget "$url"; \
    echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
    rm rustup-init; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME; \
    rustup --version; \
    cargo --version; \
    rustc --version; \
    rustup component add rustfmt;


# build from source
WORKDIR /osmosismon
COPY . /osmosismon
RUN cargo build --release

FROM alpine:3.15
COPY --from=builder /osmosismon/target/release/osmosismon /usr/local/bin/osmosismon
RUN chmod +x /usr/local/bin/osmosismon

# Install ca-certificates
RUN apk add --update ca-certificates

# install utilities
RUN apk add bash

ARG USER_ID
ARG GROUP_ID
ENV HOME /osmosismon
ENV USER_ID ${USER_ID:-1000}
ENV GROUP_ID ${GROUP_ID:-1000}

# add our user and group first
RUN addgroup -g ${GROUP_ID} osmosismon; \
    adduser -D -u ${USER_ID} -G osmosismon -h /osmosismon -s "/bin/bash" osmosismon;

# install su-exec
RUN apk add --no-cache su-exec; \
    su-exec osmosismon true;

WORKDIR /osmosismon

# Update custom cert
COPY certs/* /usr/local/share/ca-certificates/
RUN update-ca-certificates

CMD ["osmosismon"]
