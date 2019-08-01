run: ping
	sudo strace -e trace=network ./$<

%: %.ml
	ocamlfind opt -linkpkg -package lwt.unix -o $@ $^

clean:
	rm -rf ping *.cmi *.cmo

deps:
	opam install ocamlfind lwt

.PHONY: run clean deps
