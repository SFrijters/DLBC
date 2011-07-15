all: dlbc 

dlbc:
	gdmd -ofdlbc -debug=2 -vdmd /opt/usr/local/mpich2-install/lib/libmpich.a /opt/usr/local/mpich2-install/lib/libmpl.a mpi.d parameters.d stdio.d dlbc.d

test:
	gdmd -debug=showMixins -unittest -cov -ofdlbc -debug=2 -vdmd /opt/usr/local/mpich2-install/lib/libmpich.a /opt/usr/local/mpich2-install/lib/libmpl.a mpi.d parameters.d stdio.d dlbc.d

clean:
	rm -f *.o
	rm -f dlbc
