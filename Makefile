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
	rm -f tinyos.red.img tinyos.green.img
	sudo umount result/chroot/proc result/chroot/sys result/chroot/dev || true
	sudo rm -rf result

red:
	sed 's/<|ARTIFACT_NAME|>/tinyos.red.img/g' tinyos.template.yaml > tinyos.yaml
	echo "TINYBOX_COLOR=red" | tee --append build/tinybox-release
	make image

green:
	sed 's/<|ARTIFACT_NAME|>/tinyos.green.img/g' tinyos.template.yaml > tinyos.yaml
	echo "TINYBOX_COLOR=green" | tee --append build/tinybox-release
	make image

image:
	time sudo ubuntu-image classic --debug -w result -t create_chroot tinyos.yaml
	sudo mkdir -p result/chroot/proc result/chroot/sys result/chroot/dev
	sudo mount -t proc none result/chroot/proc
	sudo mount -t sysfs none result/chroot/sys
	sudo mount -o bind /dev result/chroot/dev
	time sudo ubuntu-image classic --debug -w result -r tinyos.yaml
	rm -f tinyos.yaml build/tinybox-release
	sudo umount result/chroot/proc result/chroot/sys result/chroot/dev

.PHONY: clean red green image
