all:
	dub build

doc:
	dub build -b ddox

test: clean test-clean test-build test-unittest test-runnable

test-clean: test-clean-doc test-clean-pyc test-clean-timers
	./tests/runnable/process-tests.py --clean

test-clean-doc:
	cd tests/runnable/doc ; make clean

test-clean-pyc:
	cd tests/runnable/dlbct ; make clean

test-clean-timers:
	./tests/runnable/process-tests.py --timers-clean

test-build:
	./tests/travis-ci/build-configurations.sh dmd
	./tests/travis-ci/build-configurations.sh ldc2

test-doc: test-plot
	cd tests/runnable/doc ; make

test-plot:
	./tests/runnable/process-tests.py --plot-reference

test-unittest:
	./tests/travis-ci/unittest-coverage.sh dmd

test-runnable:
	./tests/runnable/process-tests.py

clean-all: clean test-clean

clean: clean-doc
	rm -f src/dlbc/revision.d
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
	rm -f dlbc-*
	rm -f dlbc-*.o
	rm -f *.lst
	rm -f *.log
	rm -f *~
	rm -rf .dub
	rm -f dub.selections.json

clean-doc:
	rm -f docs.json
	rm -rf docs/

