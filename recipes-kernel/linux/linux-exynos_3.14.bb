inherit kernel
require recipes-kernel/linux/linux-yocto.inc

KERNEL_IMAGETYPE ?= "zImage"

COMPATIBLE_MACHINE = "(arndale)"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}-${LINUX_VERSION}:"

LINUX_VERSION ?= "3.14"
KBRANCH = "master"

SRC_URI = "git://github.com/torvalds/linux.git;bareclone=1;branch=${KBRANCH}"
PV = "${LINUX_VERSION}+git${SRCPV}"

SRCREV = "455c6fdbd219161bd09b1165f11699d6d73de11c"

SRC_URI += "file://defconfig"
