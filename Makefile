all: dlbc-dmd

test: test-dmd

release: release-dmd

revision: src/dlbc/revision.d

d2q9: release-d2q9-dmd

doc: revision doc/*ddoc
	cd doc/ ; rdmd bootDoc/generate.d ./../src --output=./html --bootdoc=.

src/dlbc/revision.d: .git/HEAD .git/index
	./get-revision.sh > $@

src/unstd/generictuple.o: src/unstd/generictuple.d
	dmd src/unstd/generictuple.d -I./src -c -ofsrc/unstd/generictuple.o

src/unstd/multidimarray.o: src/unstd/generictuple.o src/unstd/multidimarray.d
	dmd src/unstd/multidimarray.d -I./src -c -ofsrc/unstd/multidimarray.o

dlbc-dmd: revision src/unstd/multidimarray.o
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich -L-L/usr/local/stow/hdf5-1.8.13-mpich-3.1/lib64/ -L-lhdf5 -L-ldl src/main.d src/dlbc/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d src/unstd/multidimarray.o src/unstd/generictuple.o src/tests/*.d -ofdlbc -I./src -g -w -de

release-dmd: revision src/unstd/multidimarray.o
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich -L-L/usr/local/stow/hdf5-1.8.13-mpich-3.1/lib64/ -L-lhdf5 -L-ldl src/main.d src/dlbc/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d src/unstd/multidimarray.o src/unstd/generictuple.o src/tests/*.d -ofdlbc -I./src -g -w -dw -O -inline -noboundscheck -release

test-dmd: revision src/unstd/multidimarray.o
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich -L-L/usr/local/stow/hdf5-1.8.13-mpich-3.1/lib64/ -L-lhdf5 -L-ldl src/main.d src/dlbc/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d src/unstd/multidimarray.o src/unstd/generictuple.o src/tests/*.d src/tests/runnable/*.d -ofdlbc -I./src -g -w -de -unittest -debug -cov

release-d2q9-dmd: revision src/unstd/multidimarray.o
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich -L-L/usr/local/stow/hdf5-1.8.13-mpich-3.1/lib64/ -L-lhdf5 -L-ldl src/main.d src/dlbc/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d src/unstd/multidimarray.o src/unstd/generictuple.o src/tests/*.d src/tests/runnable/*.d -ofdlbc -I./src -g -w -dw -O -inline -noboundscheck -release -version=D2Q9

test-d2q9-dmd: revision src/unstd/multidimarray.o
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich -L-L/usr/local/stow/hdf5-1.8.13-mpich-3.1/lib64/ -L-lhdf5 -L-ldl src/main.d src/dlbc/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d src/unstd/multidimarray.o src/unstd/generictuple.o src/tests/*.d src/tests/runnable/*.d -ofdlbc -I./src -g -w -de -debug -cov -version=D2Q9

clean:
	rm -f src/dlbc/revision.d
	rm -rf doc/html
	rm -f *.gcda
	rm -f *.gcno
	rm -f src/*.o
	rm -f src/*~
	rm -f src/dlbc/*.o
	rm -f src/dlbc/*~
	rm -f src/dlbc/field/*.o
	rm -f src/dlbc/field/*~
	rm -f src/dlbc/io/*.o
	rm -f src/dlbc/io/*~
	rm -f src/dlbc/lb/*.o
	rm -f src/dlbc/lb/*~
	rm -f src/tests/*.o
	rm -f src/tests/*~
	rm -f src/tests/runnable/*.o
	rm -f src/tests/runnable/*~
	rm -f src/unstd/*.o
	rm -f dlbc
	rm -f dlbc.o
	rm -f *.lst

