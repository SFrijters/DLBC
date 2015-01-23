DMD=dmd
RDMD=rdmd
DOCFILES=src/main.d src/dlbc/*.d src/dlbc/elec/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d doc/*.ddoc
DFILES=src/main.d src/dlbc/*.d src/dlbc/elec/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d src/unstd/unstd.o

COMMONFLAGS=-g -w -de
TESTFLAGS=-unittest -debug -cov
RELEASEFLAGS=-O -inline -noboundscheck -release

all: dlbc-d3q19-release

doc: src/dlbc/revision.d ${DOCFILES}
	cd doc/ ; ${RDMD} bootDoc/generate.d ./../src --output=./html --bootdoc=.

src/dlbc/revision.d: .git/HEAD .git/index
	./get-revision.sh > $@

src/unstd/unstd.o: src/unstd/*.d src/unstd/c/*.d src/unstd/memory/*.d
	${DMD} src/unstd/*.d src/unstd/c/*.d src/unstd/memory/*.d -I/.src -c -ofsrc/unstd/unstd.o

dlbc-d3q19-test: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d3q19-test ${COMMONFLAGS} ${TESTFLAGS}

dlbc-d3q19: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d3q19 ${COMMONFLAGS}

dlbc-d3q19-release: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d3q19-release ${COMMONFLAGS} ${RELEASEFLAGS}

dlbc-d2q9-test: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d2q9-test ${COMMONFLAGS} ${TESTFLAGS} -version=D2Q9

dlbc-d2q9: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d2q9 ${COMMONFLAGS} -version=D2Q9

dlbc-d2q9-release: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d2q9-release ${COMMONFLAGS} ${RELEASEFLAGS} -version=D2Q9

dlbc-d1q5-test: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d1q5-test ${COMMONFLAGS} ${TESTFLAGS} -version=D1Q5

dlbc-d1q5: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d1q5 ${COMMONFLAGS} -version=D1Q5

dlbc-d1q5-release: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d1q5-release ${COMMONFLAGS} ${RELEASEFLAGS} -version=D1Q5

dlbc-d1q3-test: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d1q3-test ${COMMONFLAGS} ${TESTFLAGS} -version=D1Q3

dlbc-d1q3: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d1q3 ${COMMONFLAGS} -version=D1Q3

dlbc-d1q3-release: src/dlbc/revision.d src/unstd/unstd.o ${DFILES}
	${DMD} -L-lmpich -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc-d1q3-release ${COMMONFLAGS} ${RELEASEFLAGS} -version=D1Q3

test: clean clean-tests test-build test-unittest test-runnable

test-build: dlbc-d3q19-test dlbc-d3q19 dlbc-d3q19-release dlbc-d2q9-test dlbc-d2q9 dlbc-d2q9-release dlbc-d1q5-test dlbc-d1q5 dlbc-d1q5-release dlbc-d1q3-test dlbc-d1q3 dlbc-d1q3-release

test-unittest:
	./dlbc-d3q19-test --version
	grep -e 'covered$$' *.lst | tee cov-d3q19.log
	./dlbc-d2q9-test --version
	grep -e 'covered$$' *.lst | tee cov-d2q9.log
	./dlbc-d1q5-test --version
	grep -e 'covered$$' *.lst | tee cov-d1q5.log
	./dlbc-d1q3-test --version
	grep -e 'covered$$' *.lst | tee cov-d1q3.log

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
	rm -f src/unstd/*.o
	rm -f dlbc-*
	rm -f dlbc-*.o
	rm -f *.lst
	rm -f *.log

clean-tests:
	cd tests ; ./clean-tests.sh
