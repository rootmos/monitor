run: ping
	sudo strace -e trace=network ./$<

%: %.ml
	ocamlfind opt -linkpkg -package lwt.unix -package lwt_ppx -o $@ $^

clean:
	rm -rf ping *.cmi *.cmo

deps:
	opam install ocamlfind lwt lwt_ppx merlin

.PHONY: run clean deps
