all: clean dlbc-dmd

revision: src/revision.d

doc: revision *ddoc
	rdmd bootDoc/generate.d ./src --output=./doc/

src/revision.d: .git/HEAD .git/index
	./get-revision.sh > $@


dlbc-dmd: revision
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich src/*.d unstd/unstd/multidimarray.d -ofdlbc -D -Dd./doc -I./unstd

test-dmd: revision
	dmd -L-L/usr/local/stow/mpich-3.1/lib64 -L-lmpich src/*.d -ofdlbc -debug=showMixins -unittest -cov -g -debug=2 -D -w


clean:
	rm -f src/revision.d
	rm -rf doc
	rm -f *.gcda
	rm -f *.gcno
	rm -f *.o
	rm -f *~
	rm -f dlbc
	rm -f *.lst
