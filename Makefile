DMD=dmd
LMPICH=/usr/local/stow/mpich-3.1/lib64
LHDF5=/usr/local/stow/hdf5-1.8.13-mpich-3.1/lib64/
DFILES=src/main.d src/dlbc/*.d src/dlbc/elec/*.d src/dlbc/fields/*.d src/dlbc/io/*.d src/dlbc/lb/*.d src/unstd/unstd.o

all: dlbc-dmd

test: test-dmd

release: release-dmd

revision: src/dlbc/revision.d

# test-d2q9: test-d2q9-dmd

d2q9: dlbc-d2q9-dmd

release-d2q9: release-d2q9-dmd

doc: revision doc/*ddoc
	cd doc/ ; rdmd bootDoc/generate.d ./../src --output=./html --bootdoc=.

src/dlbc/revision.d: .git/HEAD .git/index
	./get-revision.sh > $@

unstd:
	${DMD} src/unstd/*.d src/unstd/c/*.d src/unstd/memory/*.d -I/.src -c -ofsrc/unstd/unstd.o

test-dmd: revision unstd
	${DMD} -L-L${LMPICH} -L-lmpich -L-L${LHDF5} -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc -g -dw -unittest -debug -cov

dlbc-dmd: revision unstd
	${DMD} -L-L${LMPICH} -L-lmpich -L-L${LHDF5} -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc -g -w -de

release-dmd: revision unstd
	${DMD} -L-L${LMPICH} -L-lmpich -L-L${LHDF5} -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc -g -w -dw -O -inline -noboundscheck -release

# test-d2q9-dmd: revision src/unstd/multidimarray.o
# 	${DMD} -L-L${LMPICH} -L-lmpich -L-L${LHDF5} -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc -g -w -de -unittest -debug -cov -version=D2Q9

dlbc-d2q9-dmd: revision unstd
	${DMD} -L-L${LMPICH} -L-lmpich -L-L${LHDF5} -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc -g -w -de -version=D2Q9

release-d2q9-dmd: revision unstd
	${DMD} -L-L${LMPICH} -L-lmpich -L-L${LHDF5} -L-lhdf5 -L-ldl -I./src ${DFILES} -ofdlbc -g -w -dw -O -inline -noboundscheck -release -version=D2Q9

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
	rm -f dlbc
	rm -f dlbc.o
	rm -f *.lst

