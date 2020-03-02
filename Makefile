SUDO ?=

run: server
	./$<

test-loop:
	while sleep 1; do ./test.sh; done

%: %.ml
	ocamlfind opt -thread -linkpkg -package lwt.unix -package lwt_ppx -o $@ $^

clean:
	rm -rf ping *.cmi *.cmo

deps:
	opam install ocamlfind lwt lwt_ppx merlin

.PHONY: run clean deps
