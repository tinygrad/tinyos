help:
	@echo "make red"
	@echo "       build tinyos.red.img for tinybox red"
	@echo "make green"
	@echo "       build tinyos.green.img for tinybox green"
	@echo "make clean"
	@echo "       clean up"

clean:
	rm -f tinyos.yaml build/tinybox-release
	sudo umount result/chroot/proc result/chroot/sys result/chroot/dev/pts result/chroot/dev || true
	# ensure that nothing is still mounted when we do this
	(mount | grep result/chroot) && echo "ERROR: something is still mounted" && exit 1 || true
	sudo rm -rf result

red:
	sed 's/<|ARTIFACT_NAME|>/tinyos.red.img/g' tinyos.template.yaml > tinyos.yaml
	echo "TINYBOX_COLOR=red" | tee --append build/tinybox-release
	time make image

green:
	sed 's/<|ARTIFACT_NAME|>/tinyos.green.img/g' tinyos.template.yaml > tinyos.yaml
	echo "TINYBOX_COLOR=green" | tee --append build/tinybox-release
	time make image

red-dev:
	echo "TINYBOX_DEV=1" | tee --append build/tinybox-release
	make red

green-dev:
	echo "TINYBOX_DEV=1" | tee --append build/tinybox-release
	make green

image:
	# build up till manual customization
	sudo ubuntu-image classic --debug -w result -u perform_manual_customization tinyos.yaml
	# we want to do manual customization but in a more unrestricted way
	# so we want more things to be available inside the chroot
	sudo mkdir -p result/chroot/proc result/chroot/sys result/chroot/dev/pts
	sudo mount -t proc none result/chroot/proc
	sudo mount -t sysfs none result/chroot/sys
	sudo mount -o bind /dev result/chroot/dev
	sudo mount -t devpts none result/chroot/dev/pts
	# now we can do manual customization
	sudo ubuntu-image classic --debug -w result -r -t perform_manual_customization tinyos.yaml
	# cleanup so that ubuntu-image can unchroot cleanly
	sudo umount result/chroot/proc result/chroot/sys result/chroot/dev/pts result/chroot/dev
	# now we can let ubuntu-image finish the image build
	sudo ubuntu-image classic --debug -w result -r tinyos.yaml
	# final cleanup
	rm -f tinyos.yaml build/tinybox-release

.PHONY: clean red green image
