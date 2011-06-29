all: lb 

d:
	/auto.ernie/ernie4/frijters/d/gdc/bin/usr/local/bin/gdmd -ofd-mpitest -vdmd -v -gc /auto.ernie/ernie4/frijters/d/mpich2-install/lib/libmpich.a /auto.ernie/ernie4/frijters/d/mpich2-install/lib/libmpl.a mpi.d mpitest.d 

c:
	gdc -o c-mpitest mpitest.c -I/auto.ernie/ernie4/frijters/d/mpich2-install/include -L/auto.ernie/ernie4/frijters/d/mpich2-install/lib -lmpich -lmpl

lb:
	gdmd -oflb -debug=2 -vdmd /opt/usr/local/mpich2-install/lib/libmpich.a /opt/usr/local/mpich2-install/lib/libmpl.a mpi.d lb.d

