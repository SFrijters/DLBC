DMD=dmd
RDMD=rdmd
DOCFILES=src/main.d src/dlbc/*.d src/dlbc/elec/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d doc/*.ddoc
DFILES=src/main.d src/dlbc/*.d src/dlbc/elec/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d unstandard/unstd/unstd.o
IDIRS=-I./src -I./unstandard -I./hdf5-d/src

COMMONFLAGS=-g -w -de
TESTFLAGS=-unittest -debug -cov
RELEASEFLAGS=-O -inline -noboundscheck -release

all: dlbc-d3q19-release

doc: src/dlbc/revision.d ${DOCFILES}
	cd doc/ ; ${RDMD} bootDoc/generate.d ./../src --output=./html --bootdoc=.

src/dlbc/revision.d: .git/HEAD .git/index
	./get-revision.sh > $@

unstandard/unstd/unstd.o: unstandard/unstd/*.d
	${DMD} unstandard/unstd/*.d -I/.src -c -ofunstandard/unstd/unstd.o

dlbc-d3q19-test: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d3q19-test ${COMMONFLAGS} ${TESTFLAGS}

dlbc-d3q19: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d3q19 ${COMMONFLAGS}

dlbc-d3q19-release: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d3q19-release ${COMMONFLAGS} ${RELEASEFLAGS}

dlbc-d2q9-test: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d2q9-test ${COMMONFLAGS} ${TESTFLAGS} -version=D2Q9

dlbc-d2q9: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d2q9 ${COMMONFLAGS} -version=D2Q9

dlbc-d2q9-release: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d2q9-release ${COMMONFLAGS} ${RELEASEFLAGS} -version=D2Q9

dlbc-d1q5-test: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d1q5-test ${COMMONFLAGS} ${TESTFLAGS} -version=D1Q5

dlbc-d1q5: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d1q5 ${COMMONFLAGS} -version=D1Q5

dlbc-d1q5-release: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d1q5-release ${COMMONFLAGS} ${RELEASEFLAGS} -version=D1Q5

dlbc-d1q3-test: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d1q3-test ${COMMONFLAGS} ${TESTFLAGS} -version=D1Q3

dlbc-d1q3: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d1q3 ${COMMONFLAGS} -version=D1Q3

dlbc-d1q3-release: src/dlbc/revision.d unstandard/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl ${IDIRS} ${DFILES} -ofdlbc-d1q3-release ${COMMONFLAGS} ${RELEASEFLAGS} -version=D1Q3

test: clean clean-tests test-build test-unittest test-runnable

test-build-makefile: dlbc-d3q19-test dlbc-d3q19 dlbc-d3q19-release dlbc-d2q9-test dlbc-d2q9 dlbc-d2q9-release dlbc-d1q5-test dlbc-d1q5 dlbc-d1q5-release dlbc-d1q3-test dlbc-d1q3 dlbc-d1q3-release

test-build:
	./tests/travis-ci/build-configurations.sh dmd
	./tests/travis-ci/build-configurations.sh ldc2

test-unittest:
	./tests/travis-ci/unittest-coverage.sh dmd

test-runnable:
	cd tests ; ./run-tests.sh

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

clean-tests:
	cd tests ; ./clean-tests.sh
