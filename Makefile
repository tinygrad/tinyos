help:
	@echo "make red"
	@echo "       build tinyos.red.img for tinybox red"
	@echo "make green"
	@echo "       build tinyos.green.img for tinybox green"
	@echo "make clean"
	@echo "       clean up"

clean:
	rm -f build/tinybox-release
	rm -f tinyos.yaml
	rm -f tinyos.img
	rm -f tinyos.manifest

red:
	sed 's/<|ARTIFACT_NAME|>/tinyos.red.img/g' tinyos.template.yaml > tinyos.yaml
	echo "TINYBOX_COLOR=red" | tee --append build/tinybox-release
	time sudo ubuntu-image classic --debug tinyos.yaml
	rm -f tinyos.yaml build/tinybox-release

green:
	sed 's/<|ARTIFACT_NAME|>/tinyos.green.img/g' tinyos.template.yaml > tinyos.yaml
	echo "TINYBOX_COLOR=green" | tee --append build/tinybox-release
	time sudo ubuntu-image classic --debug tinyos.yaml
	rm -f tinyos.yaml build/tinybox-release

.PHONY: clean red green
