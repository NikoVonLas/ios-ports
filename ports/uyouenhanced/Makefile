SHELL := /bin/bash
.NOTPARALLEL:
.PHONY: all fetch rootful rootless build package test clean
all: package
fetch:
	python3 scripts/fetch.py
rootful: fetch
	python3 scripts/build.py rootful
	python3 scripts/package.py rootful
rootless: fetch
	python3 scripts/build.py rootless
	python3 scripts/package.py rootless
build: fetch
	python3 scripts/build.py rootful
	python3 scripts/build.py rootless
package: build
	python3 scripts/package.py rootful
	python3 scripts/package.py rootless
test:
	./tests/run.sh
clean:
	rm -rf .build dist
