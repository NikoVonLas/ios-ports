SHELL := /bin/sh

.PHONY: all nodejs nodejs-check nodejs-fetch nodejs-build nodejs-package clean

all: nodejs

nodejs:
	$(MAKE) -C ports/nodejs all

nodejs-check:
	$(MAKE) -C ports/nodejs check

nodejs-fetch:
	$(MAKE) -C ports/nodejs fetch

nodejs-build:
	$(MAKE) -C ports/nodejs build

nodejs-package:
	$(MAKE) -C ports/nodejs package

clean:
	$(MAKE) -C ports/nodejs clean
