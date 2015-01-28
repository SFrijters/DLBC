all: clean build
	cp ../../../dlbc-d3q19-release .
	./dlbc-d3q19-release -p bdist2-3d.in -v Fatal 
	./compare-reference-data.sh

build:
	cd ../../../ ; make dlbc-d3q19-release

clean:
	rm -rf output/
	rm -f dlbc-d3q19-release

