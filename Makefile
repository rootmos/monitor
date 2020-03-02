SUDO ?=

run: server
	$(SUDO) ./$<

test-loop:
	while sleep 1; do ./test.sh; done

OCAMLOPT = ocamlfind ocamlopt -thread -package lwt.unix,lwt_ppx,str
server: server.ml monitor.mli ping.ml
	$(OCAMLOPT) -linkpkg -o $@ monitor.mli ping.ml server.ml

clean:
	rm -rf server *.cmi *.cmo *.cmx

deps:
	opam install ocamlfind lwt lwt_ppx merlin

.PHONY: run clean deps
