# this gadget can be built in two ways, either through snapcraft (and then a prebuilt gadget
# is passed to ubuntu-image), or through make ARCH=a SERIES=s by livecd-rootfs or ubuntu-image

ifdef SNAPCRAFT_STAGE
STAGEDIR ?= "$(SNAPCRAFT_STAGE)"
else
STAGEDIR ?= "$(CURDIR)/stage"
endif

# ARCH should be set by livecd-rootfs or ubuntu-image, or through
# SNAPCRAFT_TARGET_ARCH by snapcraft; output a warning if unset (e.g. local build)
ifdef SNAPCRAFT_TARGET_ARCH
ARCH := $(SNAPCRAFT_TARGET_ARCH)
endif
ifndef ARCH
ARCH := $(shell dpkg --print-architecture)
$(warning Setting ARCH to $(ARCH) for local build)
endif

ARCHIVE := $(if $(findstring $(ARCH),amd64 i386),http://archive.ubuntu.com/ubuntu/,http://ports.ubuntu.com/ubuntu-ports/)

# architecture specific names
EFI_ARCH_amd64 := x64
EFI_ARCH_arm64 := aa64
EFI_ARCH = $(EFI_ARCH_$(ARCH))
EFI_ARCH_UPPER = $(shell echo $(EFI_ARCH) | tr '[:lower:]' '[:upper:]')
GRUB_TARGET_amd64 := x86_64-efi-signed
GRUB_TARGET_arm64 := arm64-efi-signed
GRUB_TARGET = $(GRUB_TARGET_$(ARCH))
$(if $(EFI_ARCH),,$(error Unknown EFI architecture))

# SERIES should be set by livecd-rootfs or snapcraft should setup a clean environment; output a
# warning if unset (e.g. local build)
ifndef SERIES
SERIES := $(shell . /etc/os-release && echo $$UBUNTU_CODENAME)
# no target series env var in snapcraft
ifndef SNAPCRAFT_STAGE
$(warning Setting SERIES to $(SERIES) for local build)
endif
endif

DESTDIR ?= "$(CURDIR)/install"
SHIM_SIGNED := $(STAGEDIR)/usr/lib/shim/shim$(EFI_ARCH).efi.signed
SHIM_LATEST := $(SHIM_SIGNED).latest

# set LEGACY_BOOT to legacy-boot target name if we're building backwards
# compatible pc-boot.img and pc-core.img
LEGACY_BOOT := $(if $(findstring $(ARCH),amd64),legacy-boot,)

# filtered list of modules included in the signed EFI grub image, excluding
# ones that we don't think are useful in snappy. These are only used for
# legacy-boot target.
GRUB_LEGACY_MODULES = \
	all_video \
	biosdisk \
	boot \
	cat \
	chain \
	configfile \
	echo \
	ext2 \
	fat \
	font \
	gettext \
	gfxmenu \
	gfxterm \
	gfxterm_background \
	gzio \
	halt \
	jpeg \
	keystatus \
	loadenv \
	loopback \
	linux \
	memdisk \
	minicmd \
	normal \
	part_gpt \
	png \
	reboot \
	search \
	search_fs_uuid \
	search_fs_file \
	search_label \
	sleep \
	squash4 \
	test \
	true \
	btrfs \
	hfsplus \
	iso9660 \
	part_apple \
	part_msdos \
	password_pbkdf2 \
	zfs \
	zfscrypt \
	zfsinfo \
	lvm \
	mdraid09 \
	mdraid1x \
	raid5rec \
	raid6rec \
	video

all: boot install

server: boot install

desktop: boot install

# Check if we're running under snapcraft. If not, we need to 'stage' some
# packages by ourselves.
ifdef SNAPCRAFT_PROJECT_NAME
stage-package:
	$(info Skipping staging of package $(package) under snapcraft)
else
# Download the latest version of package $package for architecture $(ARCH), unpacking
# it into $(STAGEDIR). For example, the following invocation will download the
# latest version of u-boot-rpi for armhf, and unpack it under STAGEDIR:
#
#  $(MAKE) stage-package package=u-boot-rpi
#
stage-package:
	$(info Staging package $(package)...)
	mkdir -p $(STAGEDIR)/tmp
	# setup chdist APT environment for SERIES-ARCH and run apt update; -updates
	# and -security are always used	and -proposed is optionally enabled if
	# PROPOSED is non-empty, following livecd-rootfs logic
	if [ ! -d  $(STAGEDIR)/tmp/chdist ]; then \
	    chdist -d $(STAGEDIR)/tmp/chdist -a $(ARCH) create $(SERIES)-$(ARCH); \
	    echo "deb $(ARCHIVE) $(SERIES) main" >$(STAGEDIR)/tmp/chdist/$(SERIES)-$(ARCH)/etc/apt/sources.list; \
	    echo "deb $(ARCHIVE) $(SERIES)-security main" >>$(STAGEDIR)/tmp/chdist/$(SERIES)-$(ARCH)/etc/apt/sources.list; \
	    echo "deb $(ARCHIVE) $(SERIES)-updates main" >>$(STAGEDIR)/tmp/chdist/$(SERIES)-$(ARCH)/etc/apt/sources.list; \
	    if [ -n "$$PROPOSED" ]; then \
	        echo "deb $(ARCHIVE) $(SERIES)-proposed main" >>$(STAGEDIR)/tmp/chdist/$(SERIES)-$(ARCH)/etc/apt/sources.list; \
	    fi; \
	    chdist -d $(STAGEDIR)/tmp/chdist -a $(ARCH) apt $(SERIES)-$(ARCH) update; \
	fi
	# download and unpack package
	cd $(STAGEDIR)/tmp && \
	    chdist -d $(STAGEDIR)/tmp/chdist -a $(ARCH) apt $(SERIES)-$(ARCH) download $(package)
	dpkg-deb --extract $(STAGEDIR)/tmp/$(package)_*.deb $(STAGEDIR)
endif

# this generates 32-bits pc-boot.img and pc-core.img for backwards
# compatibility with non-EFI BIOSes
legacy-boot:
	$(MAKE) stage-package package=grub-pc-bin
	dd if=$(STAGEDIR)/usr/lib/grub/i386-pc/boot.img of=pc-boot.img bs=440 count=1
	/bin/echo -n -e '\x90\x90' | dd of=pc-boot.img seek=102 bs=1 conv=notrunc
	grub-mkimage -d $(STAGEDIR)/usr/lib/grub/i386-pc/ -O i386-pc -o pc-core.img -p '(,gpt2)/EFI/ubuntu' $(GRUB_LEGACY_MODULES)
	# The first sector of the core image requires an absolute pointer to the
	# second sector of the image.  Since this is always hard-coded, it means our
	# BIOS boot partition must be defined with an absolute offset.  The
	# particular value here is 2049, or 0x01 0x08 0x00 0x00 in little-endian.
	/bin/echo -n -e '\x01\x08\x00\x00' | dd of=pc-core.img seek=500 bs=1 conv=notrunc

boot: $(LEGACY_BOOT)
	$(MAKE) stage-package package=grub-efi-$(ARCH)-signed
	$(MAKE) stage-package package=shim-signed

	if [ -f "$(SHIM_LATEST)" ]; then \
		cp $(SHIM_LATEST) shim$(EFI_ARCH).efi; \
	else \
		cp $(SHIM_SIGNED) shim$(EFI_ARCH).efi; \
	fi
	cp $(STAGEDIR)/usr/lib/grub/$(GRUB_TARGET)/grub$(EFI_ARCH).efi.signed grub$(EFI_ARCH).efi
	cp $(STAGEDIR)/usr/lib/shim/BOOT$(EFI_ARCH_UPPER).CSV BOOT$(EFI_ARCH_UPPER).CSV
	cp $(STAGEDIR)/usr/lib/shim/fb$(EFI_ARCH).efi fb$(EFI_ARCH).efi
	cp $(STAGEDIR)/usr/lib/shim/mm$(EFI_ARCH).efi mm$(EFI_ARCH).efi

install: boot
	mkdir -p $(DESTDIR)
	install -m 644 \
	    $(if $(LEGACY_BOOT),pc-boot.img pc-core.img) shim$(EFI_ARCH).efi grub$(EFI_ARCH).efi \
	    BOOT$(EFI_ARCH_UPPER).CSV fb$(EFI_ARCH).efi mm$(EFI_ARCH).efi \
	    $(DESTDIR)/
	install -m 644 grub.conf grub.cfg $(DESTDIR)/
	# For classic builds we also need to prime the gadget.yaml
	mkdir -p $(DESTDIR)/meta
	ln gadget-$(ARCH).yaml gadget.yaml
	cp gadget-$(ARCH).yaml $(DESTDIR)/meta/gadget.yaml

# only used locally, not relevant for snapcraft, livecd-rootfs or ubuntu-image
clean:
	rm -rf $(STAGEDIR)
	rm -f pc-boot.img pc-core.img shim$(EFI_ARCH).efi grub$(EFI_ARCH).efi \
	    BOOT$(EFI_ARCH_UPPER).CSV fb$(EFI_ARCH).efi mm$(EFI_ARCH).efi
	rm -f gadget.yaml
	rm -rf $(DESTDIR)

.PHONY: all stage-package $(LEGACY_BOOT) boot install clean
