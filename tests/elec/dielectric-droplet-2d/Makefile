all:
	cp ../../../dlbc dlbc-d2q9
	/usr/local/stow/mpich-3.1/bin/mpirun -np 4 ./dlbc-d2q9 -p input-parameters-dielectric-droplet-2D-eq.txt -v Information

resume:
	cp ../../../dlbc dlbc-d2q9
	/usr/local/stow/mpich-3.1/bin/mpirun -np 4 ./dlbc-d2q9 -p input-parameters-dielectric-droplet-2D.txt -v Information -r dielectric-droplet-2d-20140808T182838-t00001000 

build:
	cd ../../../ ; make release-d2q9

