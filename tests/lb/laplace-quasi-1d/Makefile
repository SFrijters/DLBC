all: clean build
	cp ../../../dlbc-d1q3-release .
	cp ../../../dlbc-d1q5-release .
	cp ../../../dlbc-d2q9-release .
	cp ../../../dlbc-d3q19-release .
	./run-simulations.sh	

build:
	cd ../../../ ; make dlbc-d1q3-release
	cd ../../../ ; make dlbc-d1q5-release
	cd ../../../ ; make dlbc-d2q9-release
	cd ../../../ ; make dlbc-d3q19-release

clean:
	rm -rf output-d1q3/
	rm -rf output-d1q5/
	rm -rf output-d2q9/
	rm -rf output-d3q19/
	rm -f dlbc-d1q3-release
	rm -f dlbc-d1q5-release
	rm -f dlbc-d2q9-release
	rm -f dlbc-d3q19-release
	rm -f stdout*.txt


