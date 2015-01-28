all:
	cp ../../../dlbc dlbc-d2q9
	mpirun -np 4 ./dlbc-d2q9 -p input-parameters-dielectric-droplet-2D-eq.txt -v Information

resume:
	cp ../../../dlbc dlbc-d2q9
	mpirun -np 1 ./dlbc-d2q9 -p input-parameters-dielectric-droplet-2D.txt -v Information -r dielectric-droplet-2d-phi2-20140815T171518-t00002000 

build:
	cd ../../../ ; make release-d2q9

