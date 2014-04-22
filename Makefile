all: clean dlbc-dmd

revision: src/dlbc/revision.d

doc: revision *ddoc
	rdmd bootDoc/generate.d ./src --output=./doc/

src/dlbc/revision.d: .git/HEAD .git/index
	./get-revision.sh > $@

dlbc-dmd: revision
	dmd -L-L/usr/local/lib -L-lmpich -L-lhdf5 src/*.d unstd/unstd/multidimarray.d -ofdlbc -D -Dd./doc -I./unstd

test-dmd: revision
	dmd -L-L/usr/local/lib -L-lmpich -L-lhdf5 src/*.d -ofdlbc -debug=showMixins -unittest -cov -g -debug=2 -D -w

clean:
	rm -f src/dlbc/revision.d
	rm -rf doc
	rm -f *.gcda
	rm -f *.gcno
	rm -f *.o
	rm -f *~
	rm -f dlbc
	rm -f *.lst
