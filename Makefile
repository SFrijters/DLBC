all: dlbc 

dlbc:
	gdmd -ofdlbc -debug=2 -vdmd /opt/usr/local/mpich2-install/lib/libmpich.a /opt/usr/local/mpich2-install/lib/libmpl.a mpi.d parameters.d stdio.d dlbc.d parallel.d lattice.d

test:
	gdmd -debug=showMixins -unittest -cov -ofdlbc -g -debug=2 -vdmd /opt/usr/local/mpich2-install/lib/libmpich.a /opt/usr/local/mpich2-install/lib/libmpl.a mpi.d parameters.d stdio.d dlbc.d parallel.d lattice.d

clean:
	rm -rf doc
	rm -f *.gcda
	rm -f *.gcno
	rm -f *.o
	rm -f *~
	rm -f dlbc
