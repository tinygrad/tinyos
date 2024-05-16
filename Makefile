all: download-deps build

clean:
	rm -rf build/deps
	rm -rf build/venv
	rm -f tinyos.img
	rm -f tinyos.manifest

download-deps:
	mkdir -p build/deps
	[ -f build/deps/gum.deb ] || curl -o build/deps/gum.deb -L "https://github.com/charmbracelet/gum/releases/download/v0.14.0/gum_0.14.0_amd64.deb"

build-venv:
	bash build/build-venv.sh

build: download-deps build-venv
	time sudo ubuntu-image classic --debug tinyos.yaml

.PHONY: clean download-deps build-venv build
