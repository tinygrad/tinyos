= Kernels and Bootloaders =

The default kernels and bootloaders are not to be installed by debootstrap,
and *-minimal metapackages should not depend on them; however, they do need
to end up on CD images and in live filesystems. We therefore put them in a
separate seed.

We seed both linux-* and linux-image-* so that it's easier to build CD
images without the restricted component. The linux-* kernels include
restricted modules.

 * Kernel-Stem: linux linux-image

== i386 ==

 * grub-pc [amd64 i386]
 * ${Kernel-Stem}-generic [i386]          # our chosen default install kernel

== ppc64el ==

 * grub-ieee1275 [ppc64el]
 * ${Kernel-Stem}-generic [ppc64el]       # default install kernel for ppc64el

== amd64 ==

 * ${Kernel-Stem}-generic [amd64]         # amd64 kernel, works on all machines though not optimised

== armel / armhf ==

 * ${Kernel-Stem}-generic [armhf]         # multiplatform kernel, will eventually replace others

== arm64 ==

 * grub-efi-arm64 [arm64]
 * ${Kernel-Stem}-generic [arm64]

== s390x ==

 * ${Kernel-Stem}-generic [s390x]
 * s390-tools [s390x]

== riscv64 ==

 * flash-kernel [riscv64]

== Germinate workarounds ==

Stop grub-common -> base-files -> awk from selecting gawk. (Since the boot seed doesn't inherit from required for arcane reasons, this is the only way we can make this work reliably ...)

 * mawk
