all: clean version dlbc 

version:
	@echo 'immutable string revisionNumber  = "'`git rev-parse HEAD`'";' > src/revision.d
	@git diff --stat | awk 'BEGIN {printf("immutable string revisionChanges = \"")} {printf("\\n%s",$$0)} END {printf("\";\n")}'>> src/revision.d 

dlbc:
	gdmd -ofdlbc -vdmd /opt/usr/local/mpich2-install/lib/libmpich.a /opt/usr/local/mpich2-install/lib/libmpl.a src/*.d

test:
	gdmd -debug=showMixins -unittest -cov -ofdlbc -g -debug=2 -vdmd /opt/usr/local/mpich2-install/lib/libmpich.a /opt/usr/local/mpich2-install/lib/libmpl.a src/*.d

clean:
	rm -f src/revision.d
	rm -rf doc
	rm -f *.gcda
	rm -f *.gcno
	rm -f *.o
	rm -f *~
	rm -f dlbc
