SHELL := /bin/sh

.PHONY: all nodejs nodejs-check nodejs-fetch nodejs-build nodejs-package codex codex-check codex-fetch codex-build codex-package codex-repo codex-test clean

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

codex:
	$(MAKE) -C ports/codex package

codex-check:
	$(MAKE) -C ports/codex check

codex-fetch:
	$(MAKE) -C ports/codex fetch

codex-build:
	$(MAKE) -C ports/codex build

codex-package:
	$(MAKE) -C ports/codex package

codex-repo:
	$(MAKE) -C ports/codex repo

codex-test:
	$(MAKE) -C ports/codex test

clean:
	$(MAKE) -C ports/nodejs clean
	$(MAKE) -C ports/codex clean
