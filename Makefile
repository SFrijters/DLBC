all:
	dub build

doc: src/dlbc/revision.d src/main.d src/dlbc/*.d src/dlbc/elec/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d doc/*.ddoc
	cd src/ ; ln -s ../unstandard/unstd
	cd src/ ; ln -s ../hdf5-d/src/hdf5
	cd doc/ ; rdmd bootDoc/generate.d ./../src --output=./html --bootdoc=.
	rm -f src/unstd
	rm -f src/hdf5

src/dlbc/revision.d: .git/HEAD .git/index
	./get-revision.sh > $@

test: clean test-clean test-build test-unittest test-runnable

test-clean: test-clean-doc
	./tests/runnable/run-tests.py --clean

test-clean-doc:
	cd tests/runnable/doc ; make clean

test-build:
	./tests/travis-ci/build-configurations.sh dmd
	./tests/travis-ci/build-configurations.sh ldc2

test-doc: test-plot
	cd tests/runnable/doc ; make

test-plot:
	./tests/runnable/run-tests.py --plot-reference

test-unittest:
	./tests/travis-ci/unittest-coverage.sh dmd

test-runnable:
	./tests/runnable/run-tests.py

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
	rm -f unstandard/unstd/*.o
	rm -f unstandard/*.a
	rm -rf unstandard/.dub
	rm -f hdf5-d/*.a
	rm -rf hdf5-d/.dub
	rm -f dlbc-*
	rm -f dlbc-*.o
	rm -f *.lst
	rm -f *.log
	rm -f *~
	rm -rf .dub
	rm -f dub.selections.json


