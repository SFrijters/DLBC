all: clean build
	cp ../../../dlbc-d2q9-release .
	/usr/local/stow/mpich-3.1/bin/mpirun -np 1 ./dlbc-d2q9-release -p input-parameters-dielectric-capacitor-2D.txt -v Fatal 
	./compare-reference-data.sh

build:
	cd ../../../ ; make dlbc-d2q9-release

clean:
	rm -rf output/
	rm -f dlbc-d2q9-release

