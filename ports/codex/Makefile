SHELL := /bin/bash

.PHONY: all check fetch build package repo test clean device-info install

all: package

check:
	./scripts/check-toolchain.sh

fetch:
	./scripts/fetch-source.sh

build: check fetch
	./scripts/build.sh

package: build
	./scripts/package.sh

repo:
	./scripts/make-repo.py

test:
	./tests/static.sh

device-info:
	./scripts/device-info.sh

install:
	./scripts/install-device.sh

clean:
	rm -rf .build dist
