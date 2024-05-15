all: download-deps build

clean:
	rm -rf build/deps
	rm -f tinyos.img
	rm -f tinyos.manifest

download-deps:
	mkdir -p build/deps
	curl -o build/deps/gum.deb -L "https://github.com/charmbracelet/gum/releases/download/v0.14.0/gum_0.14.0_amd64.deb"

build: download-deps
	time sudo ubuntu-image classic --debug tinyos.yaml

.PHONY: clean download-deps build
