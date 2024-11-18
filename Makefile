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
	$(SUDO) install --owner=0 --mode=0755 client.exe $(PREFIX)/bin/$(PROGRAM_PREFIX)client

PKGs = lwt.unix,lwt_ppx,str,cohttp-lwt-unix,atdgen,logs.fmt

server.exe: \
	$(call atd, ip_resp) \
	statfs_impl.o statfs.ml \
	utils.ml monitor.ml fs.ml ping.ml location.ml server.ml
	$(BUILDML_OCAMLC) -o $@ $^

%.o: %.c
	$(OCAMLFIND) ocamlc -c $^

#clean:
	#rm -rf server *.cmi *.cmo *.cmx *.o *_t.ml* *_j.ml*

#deps:
	#opam install ocamlfind lwt lwt_ppx merlin tls cohttp-lwt-unix atdgen logs
