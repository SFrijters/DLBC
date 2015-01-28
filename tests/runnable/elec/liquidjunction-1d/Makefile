all: clean build
	cp ../../../dlbc-d1q3-release .
	mpirun -np 1 ./dlbc-d1q3-release -p input-parameters-liquidjunction-1D.txt -v Fatal 
	./compare-reference-data.sh

build:
	cd ../../../ ; make dlbc-d1q3-release

clean:
	rm -rf output/
	rm -f dlbc-d1q3-release

extended-plot: clean build
	cp ../../../dlbc-d1q3-release .
	mpirun -np 1 ./dlbc-d1q3-release -p input-parameters-liquidjunction-1D-extended-plot.txt -v Fatal 

clean-extended-plot:
	rm -rf output-extended-plot/

