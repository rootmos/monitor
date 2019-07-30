CC = ocamlc
DEPS = 

run: ping
	./$<

%: %.ml
	ocamlfind $(CC) -o $@ $^

clean:
	rm -rf gen *.cmi *.cmo *_{j,t}.{ml,mli}

deps:
	opam install ocamlfind $(DEPS)

.PHONY: run all clean deps
