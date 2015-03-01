all: clean build
	cp ../../../dlbc-d2q9-release .
	./dlbc-d2q9-release -p dielectric-droplet-bdist2-2d-eq.in -v Notification

resume: build
	cp ../../../dlbc-d2q9-release .
	./dlbc-d2q9-release -p dielectric-droplet-bdist2-2d.in -v Information -r dielectric-droplet-bdist2-2d-eq%-20141208T180106-t00002000

build:
	cd ../../../ ; make dlbc-d2q9-release

clean:
	rm -rf output/
	rm -f dlbc-d2q9-release

