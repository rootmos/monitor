.DEFAULT_GOAL := build
include buildml.mk

.PHONY: build
build: server.exe

BUILDML_OCAMLC_OPTS = -thread -package str

server.exe: \
	$(call atd, ip_resp) \
	statfs_impl.o statfs.ml \
	utils.ml monitor.ml fs.ml ping.ml location.ml server.ml
	$(BUILDML_OCAMLC) -o $@ $^
