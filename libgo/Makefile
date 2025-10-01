# Get version from .git.
date=$(shell git log -1 --format="%cd" --date=short | sed s/-//g)
count=$(shell git rev-list --count HEAD)
commit=$(shell git rev-parse --short HEAD)

ifeq ($(wildcard .git/.),)
	VERSION ?= unstable-0.nogit
else
	VERSION ?= unstable-0.nogit
endif

ifndef CGO_ENABLED
	CGO_ENABLED := 0
endif
NAME=screengot
BINDIR=binlib
NDK_BIN=$(ANDROID_NDK)/toolchains/llvm/prebuilt/linux-x86_64/bin

GOBUILD=CGO_ENABLED=1 go build -o $(NAME)-$@.so -trimpath -ldflags="-w -s" -buildmode=c-shared ./
all: juicity-server juicity-client

juicity-server:
	CGO_ENABLED=$(CGO_ENABLED) go build -o $@ -trimpath  \
		 -ldflags "-s -w -buildmode=c-shared -X github.com/juicity/juicity/config.Version=$(VERSION)" \
		 ./cmd/server

juicity-client:
	CGO_ENABLED=$(CGO_ENABLED) go build -o $@ -trimpath \
		 -ldflags "-s -w -buildmode=c-shared -X github.com/juicity/juicity/config.Version=$(VERSION)" \
		 ./cmd/client
android-arm64:
	env GOOS=android GOARCH=arm64 CC=$(NDK_BIN)/aarch64-linux-android21-clang $(GOBUILD)
linux-amd64:
	env GOOS=linux GOARCH=amd64  $(GOBUILD)

.PHONY: juicity-server juicity-client all
