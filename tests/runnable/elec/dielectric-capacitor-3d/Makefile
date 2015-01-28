all: clean build
	cp ../../../dlbc-d3q19-release .
	mpirun -np 1 ./dlbc-d3q19-release -p input-parameters-dielectric-capacitor-3D.txt -v Fatal 
	./compare-reference-data.sh

build:
	cd ../../../ ; make dlbc-d3q19-release

clean:
	rm -rf output/
	rm -f dlbc-d3q19-release

