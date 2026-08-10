SHELL := /bin/sh

.PHONY: all check fetch build package clean

all: check fetch build package

check:
	./scripts/check-toolchain.sh

fetch:
	./scripts/fetch-source.sh

build:
	./scripts/build.sh

package:
	./scripts/package.sh

clean:
	rm -rf build dist
