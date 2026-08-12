SHELL := /bin/sh

.PHONY: all nodejs nodejs-check nodejs-fetch nodejs-build nodejs-package codex codex-check codex-fetch codex-build codex-package codex-repo codex-test github-cli github-cli-check github-cli-fetch github-cli-build github-cli-package github-cli-repo github-cli-test clean

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

github-cli:
	$(MAKE) -C ports/github-cli package

github-cli-check:
	$(MAKE) -C ports/github-cli check

github-cli-fetch:
	$(MAKE) -C ports/github-cli fetch

github-cli-build:
	$(MAKE) -C ports/github-cli build

github-cli-package:
	$(MAKE) -C ports/github-cli package

github-cli-repo:
	$(MAKE) -C ports/github-cli repo

github-cli-test:
	$(MAKE) -C ports/github-cli test

clean:
	$(MAKE) -C ports/nodejs clean
	$(MAKE) -C ports/codex clean
	$(MAKE) -C ports/github-cli clean
