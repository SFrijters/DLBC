all: clean build
	cp ../../../dlbc-d2q9-release .
	mpirun -np 1 ./dlbc-d2q9-release -p input-parameters-liquidjunction-2D.txt -v Fatal 
	./compare-reference-data.sh

build:
	cd ../../../ ; make dlbc-d2q9-release

clean:
	rm -rf output/
	rm -f dlbc-d2q9-release

extended-plot: clean build
	cp ../../../dlbc-d2q9-release .
	mpirun -np 1 ./dlbc-d2q9-release -p input-parameters-liquidjunction-2D-extended-plot.txt -v Fatal

clean-extended-plot:
	rm -rf output-extended-plot/

