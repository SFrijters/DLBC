all:
	cp ../../../dlbc dlbc-d3q19
	/usr/local/stow/mpich-3.1/bin/mpirun -np 1 ./dlbc-d3q19 -p input-parameters-dielectric-capacitor-3D.txt -v Debug 

build:
	cd ../../../ ; make release 

