# tinyos

the os image builder for the tinybox.

uses [`ubuntu-image`](https://github.com/canonical/ubuntu-image)

run `make green` to build the image for tinybox green or run `make red` to build the image for tinybox red.

## Contributing Notes

`userspace/etc/tinybox-update-stage` contains the current system update stage, `service/autoupdate-tinybox.sh` will check this file and run all update stages in `service/autoupdate/` that are greater than the current stage. `userspace/etc/tinybox-update-stage` should be bumped manually when a breaking change is done alongside a corresponding update stage script.

```bash
./
├── build
│   ├── in-chroot-post.d
│   │   ├── 00update.sh
│   │   ├── 01install-packages.sh
│   │   ├── 02install-drivers.sh
│   │   ├── 05install-tinygrad__user.sh
│   │   ├── 06install-torch__user.sh
│   │   ├── 10build-venv.sh
│   │   ├── 11symlink.sh
│   │   ├── 20replace-motd.sh
│   │   ├── 21correct-tinychat-device.sh
│   │   └── 50finalize.sh
│   ├── in-chroot-pre.d
│   │   ├── 00release.sh
│   │   ├── 10create-user.sh
│   │   └── 20locale.sh
│   └── in-chroot.sh
├── Makefile
├── pc-gadget
│   ├── gadget-amd64.yaml
│   ├── gadget-arm64.yaml
│   ├── grub.cfg
│   ├── grub.conf -> grub.cfg
│   ├── icon.png
│   ├── Makefile
│   ├── README.md
│   └── snapcraft.yaml
├── README.md
├── result [error opening dir]
├── service
│   ├── autoupdate
│   │   └── 00001-tinychat-venv.sh
│   ├── autoupdate-tinybox.service
│   ├── autoupdate-tinybox.sh
│   ├── buttonservice.py
│   ├── buttonservice.service
│   ├── displayservice.py
│   ├── displayservice.service
│   ├── logo.png
│   ├── poweroff.service
│   ├── poweroff.sh
│   ├── reboot.service
│   ├── reboot.sh
│   ├── sleeping.service
│   ├── sleeping.sh
│   ├── tinychat
│   │   └── redbean.com
│   └── tinychat.service
├── setup
│   ├── firstboot.sh
│   ├── firstsetup.sh
│   ├── fixdisk.sh
│   ├── monitortemps.sh
│   ├── populateraid.sh
│   ├── provision.service
│   ├── provision.sh
│   ├── raidsetup.sh
│   ├── secondboot.service
│   ├── secondboot.sh
│   ├── setbmcpass.sh
│   └── trainresnet.sh
├── tinygrad
│   └── ...
├── tinyos.template.yaml
├── tinyturing
│   ├── display.py
│   ├── flake.lock
│   ├── flake.nix
│   ├── font.npy
│   └── README.md
├── tools
│   ├── fan-control
│   ├── fan-control_completion.sh
│   ├── power-limit
│   └── power-limit_completion.sh
└── userspace
    ├── etc
    │   ├── apt
    │   │   ├── apt.conf.d
    │   │   │   └── 50unattended-upgrades
    │   │   ├── keyrings
    │   │   │   ├── charm.gpg
    │   │   │   └── rocm.gpg
    │   │   ├── preferences.d
    │   │   │   └── rocm-pin-600
    │   │   └── sources.list.d
    │   │       ├── amdgpu-rocm.list
    │   │       └── charm.list
    │   ├── default
    │   │   └── grub
    │   ├── ld.so.conf.d
    │   │   └── rocm.conf
    │   ├── mdadm
    │   │   └── mdadm.conf
    │   ├── modprobe.d
    │   │   └── amdgpu.conf
    │   ├── profile.d
    │   │   └── cuda.sh
    │   ├── tinybox-update-stage
    │   └── tinychat.env
    └── home
        └── tiny
```
