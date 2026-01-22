PROGRAM_PREFIX = monitor-
PREFIX ?= /usr/local

SUDO ?=

.PHONY: install
install: build
	$(SUDO) install --owner=0 --mode=4755 src/server.exe $(PREFIX)/bin/$(PROGRAM_PREFIX)server
	$(SUDO) install --owner=0 --mode=0755 client $(PREFIX)/bin/$(PROGRAM_PREFIX)client

.PHONY: build
build:
	./buildml -R. -C src -m build

.PHONY: clean
clean:
	./buildml -R. -C src -m clean

.PHONY: deepclean
deepclean: clean
	rm -rf .opam .switch* .deps*
