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
NAME=gofalow
BINDIR=binlib
NDK_BIN=$(ANDROID_NDK)/toolchains/llvm/prebuilt/linux-x86_64/bin

GOBUILD=CGO_ENABLED=1 go build -o $(NAME)-$@.so -trimpath -ldflags="-w -s" -buildmode=c-shared ./cmd
all: linux-amd64 android-arm64

android-arm64:
	env GOOS=android GOARCH=arm64 CC=$(NDK_BIN)/aarch64-linux-android21-clang $(GOBUILD)
linux-amd64:
	env GOOS=linux GOARCH=amd64  $(GOBUILD)

.PHONY: linux-amd64 android-arm64 all 
