all: clean build
	cp ../../../dlbc-d2q9-release .
	./run-simulations.sh
	./compare-reference-data.sh

build:
	cd ../../../ ; make dlbc-d2q9-release

clean:
	rm -rf output/
	rm -f dlbc-d2q9-release
	rm -f stdout.txt

