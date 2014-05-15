all: clean dlbc-dmd

revision: src/dlbc/revision.d

doc: revision *ddoc
	rdmd bootDoc/generate.d ./src --output=./doc/

src/dlbc/revision.d: .git/HEAD .git/index
	./get-revision.sh > $@

dlbc-dmd: revision
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich src/main.d src/dlbc/*.d src/dlbc/fields/*.d src/unstd/multidimarray.d -ofdlbc -I./src

test-dmd: revision
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich src/main.d src/dlbc/*.d src/dlbc/fields/*.d src/unstd/*.d -ofdlbc -I./src -unittest -cov -g -debug=2

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
