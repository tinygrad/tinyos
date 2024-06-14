all: build

clean:
	rm -rf build/venv
	rm -f tinyos.img
	rm -f tinyos.manifest

build-venv:
	bash build/build-venv.sh

build: build-venv
	time sudo ubuntu-image classic --debug tinyos.yaml

.PHONY: clean build-venv build
