all: clean dlbc-dmd

revision: src/dlbc/revision.d

doc: revision *ddoc
	rdmd bootDoc/generate.d ./src --output=./doc/

src/dlbc/revision.d: .git/HEAD .git/index
	./get-revision.sh > $@

dlbc-dmd: revision
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich src/main.d src/dlbc/*.d src/dlbc/field/*.d src/unstd/multidimarray.d -ofdlbc -D -Dd./doc -I./src

test-dmd: revision
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich src/*.d -ofdlbc -debug=showMixins -unittest -cov -g -debug=2 -D -w

clean:
	rm -f src/dlbc/revision.d
	rm -rf doc
	rm -f *.gcda
	rm -f *.gcno
	rm -f src/*.o
	rm -f src/*~
	rm -f src/dlbc/*.o
	rm -f src/dlbc/*~
	rm -f src/dlbc/field/*.o
	rm -f src/dlbc/field/*~
	rm -f dlbc
	rm -f *.lst
