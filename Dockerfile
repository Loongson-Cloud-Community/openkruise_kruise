# Build the manager binary
FROM cr.loongnix.cn/library/golang:1.15-alpine as builder

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
#RUN go mod download

# Copy the go source
COPY main.go main.go
COPY apis/ apis/
COPY cmd/ cmd/
COPY pkg/ pkg/
COPY vendor/ vendor/

# Build
RUN CGO_ENABLED=0 GO111MODULE=on go build -mod=vendor -a -o manager main.go \
  && CGO_ENABLED=0 GO111MODULE=on go build -mod=vendor -a -o daemon ./cmd/daemon/main.go

# Use Ubuntu 20.04 LTS as base image to package the manager binary
FROM cr.loongnix.cn/loongson/loongnix:20
# This is required by daemon connnecting with cri
RUN bash -c "rm -f /usr/sbin/{ip,lsmod,traceroute,udevadm}"  
RUN ln -s /usr/bin/* /usr/sbin/ && apt-get update -y \
  && apt-get install --no-install-recommends -y ca-certificates \
  && apt-get clean && rm -rf /var/log/*log /var/lib/apt/lists/* /var/log/apt/* /var/lib/dpkg/*-old /var/cache/debconf/*-old
WORKDIR /
COPY --from=builder /workspace/manager .
COPY --from=builder /workspace/daemon ./kruise-daemon
ENTRYPOINT ["/manager"]
