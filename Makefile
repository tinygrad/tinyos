help:
	@echo "make setup"
	@echo "       installs ubuntu-image"
	@echo "make red"
	@echo "       build tinyos.red.img for tinybox red"
	@echo "make green"
	@echo "       build tinyos.green.img for tinybox green"
	@echo "make core"
	@echo "       build tinyos.core.img for tinybox core"
	@echo "make red-dev"
	@echo "       build tinyos.red.img development image for tinybox red"
	@echo "make green-dev"
	@echo "       build tinyos.green.img development image for tinybox green"
	@echo "make core-dev"
	@echo "       build tinyos.core.img development image for tinybox core"
	@echo "make clean"
	@echo "       clean up"

setup:
	sudo snap install ubuntu-image --classic --edge

clean:
	rm -f tinyos.yaml build/tinybox-release
	sudo umount result/chroot/proc result/chroot/sys result/chroot/dev/pts result/chroot/dev || true
	# ensure that nothing is still mounted when we do this
	(mount | grep result/chroot) && echo "ERROR: something is still mounted" && exit 1 || true
	sudo rm -rf result

red: setup
	sed 's/<|ARTIFACT_NAME|>/tinyos.red.img/g' tinyos.template.yaml > tinyos.yaml
	sed -i 's/<|UBUNTU_SERIES|>/noble/g' tinyos.yaml
	sed -i 's/<|UBUNTU_VERSION|>/24.04/g' tinyos.yaml
	echo "TINYBOX_COLOR=red" | tee --append build/tinybox-release
	time make image

green: setup
	sed 's/<|ARTIFACT_NAME|>/tinyos.green.img/g' tinyos.template.yaml > tinyos.yaml
	sed -i 's/<|UBUNTU_SERIES|>/noble/g' tinyos.yaml
	sed -i 's/<|UBUNTU_VERSION|>/24.04/g' tinyos.yaml
	echo "TINYBOX_COLOR=green" | tee --append build/tinybox-release
	time make image

core: setup
	sed 's/<|ARTIFACT_NAME|>/tinyos.core.img/g' tinyos.template.yaml > tinyos.yaml
	sed -i 's/<|UBUNTU_SERIES|>/noble/g' tinyos.yaml
	sed -i 's/<|UBUNTU_VERSION|>/24.04/g' tinyos.yaml
	echo "TINYBOX_COLOR=core" | tee --append build/tinybox-release
	echo "TINYBOX_CORE=1" | tee --append build/tinybox-release
	time make image

red-dev: setup
	echo "TINYBOX_DEV=1" | tee --append build/tinybox-release
	make red

green-dev: setup
	echo "TINYBOX_DEV=1" | tee --append build/tinybox-release
	make green

core-dev: setup
	echo "TINYBOX_DEV=1" | tee --append build/tinybox-release
	make core

image:
	sed -i 's/<|CURRENT_DIR|>/$(shell pwd | sed 's/\//\\\//g')/g' tinyos.yaml
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
	sudo umount result/chroot/sys/firmware/efi/efivars
	sudo umount result/chroot/proc result/chroot/sys result/chroot/dev/pts result/chroot/dev
	sudo umount result/chroot/proc result/chroot/sys result/chroot/dev/pts result/chroot/dev
	# now we can let ubuntu-image finish the image build
	sudo ubuntu-image classic --debug -w result -r tinyos.yaml
	# final cleanup
	rm -f tinyos.yaml build/tinybox-release

.PHONY: setup clean red green red-dev green-dev image
