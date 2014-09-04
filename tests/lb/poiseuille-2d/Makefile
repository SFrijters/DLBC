all: clean build
	cp ../../../dlbc-d2q9-release .
	mpirun -np 1 ./dlbc-d2q9 -p input-parameters-poiseuille-2D.txt -v Fatal 
	./compare-reference-data.sh

build:
	cd ../../../ ; make dlbc-d2q9-release

clean:
	rm -rf output/
	rm -f dlbc-d2q9-release

