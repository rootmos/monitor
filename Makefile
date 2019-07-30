CC = ocamlc
DEPS = unix

run: ping
	sudo strace -e trace=network ./$<

%: %.ml
	ocamlfind $(CC) -linkpkg -package $(DEPS) -o $@ $^

clean:
	rm -rf ping *.cmi *.cmo

deps:
	opam install ocamlfind $(DEPS)

.PHONY: run clean deps
