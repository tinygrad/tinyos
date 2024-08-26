# tinyos

the os image builder for the tinybox.

uses [`ubuntu-image`](https://github.com/canonical/ubuntu-image) so should run on any recent ubuntu-based system with snap support.

run `make green` to build the image for tinybox green or run `make red` to build the image for tinybox red.

## Contributing Notes

`userspace/etc/tinybox-update-stage` contains the current system update stage, `service/autoupdate-tinybox.sh` will check this file and run all update stages in `service/autoupdate/` that are greater than the current stage. `userspace/etc/tinybox-update-stage` should be bumped manually when a breaking change is done alongside a corresponding update stage script.
