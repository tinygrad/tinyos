help:
	@echo "make red"
	@echo "       build tinyos.red.img for tinybox red"
	@echo "make green"
	@echo "       build tinyos.green.img for tinybox green"
	@echo "make clean"
	@echo "       clean up"

clean:
	rm -f userspace/etc/tinybox-release
	rm -f tinyos.yaml
	rm -f tinyos.img
	rm -f tinyos.manifest

red:
	sed 's/<|ARTIFACT_NAME|>/tinyos.red.img/g' tinyos.template.yaml > tinyos.yaml
	echo "COLOR=red" | tee --append userspace/etc/tinybox-release
	time sudo ubuntu-image classic --debug tinyos.yaml
	rm -f tinyos.yaml userspace/etc/tinybox-release

green:
	sed 's/<|ARTIFACT_NAME|>/tinyos.green.img/g' tinyos.template.yaml > tinyos.yaml
	echo "COLOR=green" | tee --append userspace/etc/tinybox-release
	time sudo ubuntu-image classic --debug tinyos.yaml
	rm -f tinyos.yaml userspace/etc/tinybox-release

.PHONY: clean red green
