PROGRAM_PREFIX = monitor-
PREFIX ?= /usr/local

SUDO ?=

run: server
	$(SUDO) ./$<

test-loop:
	while sleep 1; do ./test.sh; done

install: server client
	$(SUDO) install --owner=0 --mode=4755 server $(PREFIX)/bin/$(PROGRAM_PREFIX)server
	$(SUDO) install --owner=0 --mode=0755 client $(PREFIX)/bin/$(PROGRAM_PREFIX)client

PKGs = lwt.unix,lwt_ppx,str,cohttp-lwt-unix,atdgen,logs.fmt

define atd
$(1)_t.mli $(1)_t.ml $(1)_j.mli $(1)_j.ml
endef

%_t.mli %_t.ml %_j.mli %_j.ml: %.atd
	atdgen -t $<
	atdgen -j $<

OCAMLFIND = ocamlfind
OCAMLOPT = $(OCAMLFIND) ocamlopt -thread -package $(PKGs)
server: \
	$(call atd, ip_resp) \
	statfs_impl.o statfs.ml \
	utils.ml monitor.ml fs.ml ping.ml location.ml server.ml
	$(OCAMLOPT) -linkpkg -o $@ $^

%.o: %.c
	$(OCAMLFIND) ocamlc -c $^

clean:
	rm -rf server *.cmi *.cmo *.cmx *.o *_t.ml* *_j.ml*

deps:
	opam install ocamlfind lwt lwt_ppx merlin tls cohttp-lwt-unix atdgen logs

.PHONY: run clean deps
