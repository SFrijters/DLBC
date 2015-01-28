all: clean build
	cp ../../../dlbc-d1q3-release .
	./run-simulations.sh
	./compare-reference-data.sh

build:
	cd ../../../ ; make dlbc-d1q3-release

clean:
	rm -rf output/
	rm -f dlbc-d1q3-release

