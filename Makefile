.DEFAULT_GOAL := build
include buildml.mk

PROGRAM_PREFIX = monitor-
PREFIX ?= /usr/local

SUDO ?=

.PHONY: build
build: server.exe

.PHONY: install
install: build
	$(SUDO) install --owner=0 --mode=4755 server.exe $(PREFIX)/bin/$(PROGRAM_PREFIX)server
	$(SUDO) install --owner=0 --mode=0755 client $(PREFIX)/bin/$(PROGRAM_PREFIX)client

BUILDML_OCAMLC_OPTS = -thread -package str

server.exe: \
	$(call atd, ip_resp) \
	statfs_impl.o statfs.ml \
	utils.ml monitor.ml fs.ml ping.ml location.ml server.ml
	$(BUILDML_OCAMLC) -o $@ $^
