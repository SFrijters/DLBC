all:
	cp ../../../dlbc dlbc-d3q19
	mpirun -np 4 ./dlbc-d3q19 -p input-parameters-dielectric-droplet-3D-eq.txt -v Information

resume:
	cp ../../../dlbc dlbc-d3q19
	mpirun -np 4 ./dlbc-d3q19 -p input-parameters-dielectric-droplet-3D.txt -v Information -r dielectric-droplet-20140807T164102-t00001000

build:
	cd ../../../ ; make release

