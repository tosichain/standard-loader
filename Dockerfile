# =============================================================================
FROM alpine:3.14.0 AS image-base

RUN apk --no-cache add e2fsprogs coreutils xxd

# =============================================================================

FROM golang:1.19 as go-car-build-amd64
RUN apt-get update && apt-get install -y llvm 

WORKDIR /app

RUN git clone https://github.com/tosichain/go-car

RUN cd go-car/cmd/car && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build
RUN llvm-strip -s /app/go-car/cmd/car/car

# =============================================================================
FROM golang:1.19 as go-car-build-riscv64

WORKDIR /app
RUN apt-get update && apt-get install -y llvm 

RUN git clone https://github.com/tosichain/go-car

RUN cd go-car/cmd/car && GOOS=linux GOARCH=riscv64 CGO_ENABLED=0 go build
RUN llvm-strip -s /app/go-car/cmd/car/car

FROM image-base AS image

WORKDIR /

RUN mkdir -p /opt/amd64/bin /opt/riscv64/bin

COPY --from=go-car-build-amd64 "/app/go-car/cmd/car/car" "/opt/amd64/bin/car"
COPY --from=go-car-build-riscv64 "/app/go-car/cmd/car/car" "/opt/riscv64/bin/car"

COPY ./resolv.conf /etc/resolv.conf 
COPY ./startup /startup
COPY ./qemu-init /qemu-init
COPY ./empty.car /empty.car

FROM alpine:3.17.0 AS buildimg
RUN apk add squashfs-tools
COPY --from=image / /image
RUN mksquashfs /image /loader.squashfs -Xcompression-level 22 -comp zstd -reproducible -all-root -mkfs-time 0 -all-time 0
FROM busybox
COPY --from=buildimg /loader.squashfs /loader.squashfs
