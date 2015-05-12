inherit image_types

IMAGE_BOOTLOADER ?= "u-boot"

# 8GiB sd card
DISK_SIZE = "7948206080"

# Handle u-boot suffixes
UBOOT_SUFFIX ?= "bin"
UBOOT_SUFFIX_SDCARD ?= "${UBOOT_SUFFIX}"

#BOOT components
UBOOT_B1_POS ?= "1"
UBOOT_B2_POS ?= "17"
UBOOT_BIN_POS ?= "49"
UBOOT_TZSW_POS ?= "719"
UBOOT_ENV_POS ?= "1231"



# Boot partition volume id
BOOTDD_VOLUME_ID ?= "${MACHINE}"

# Set alignment to 1MB [in KiB]
IMAGE_ROOTFS_ALIGNMENT = "2048"

SDIMG_ROOTFS_TYPE ?= "ext4"
SDIMG_ROOTFS = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.${SDIMG_ROOTFS_TYPE}"

# Boot partition size [in KiB]
BOOT_SPACE ?= "102400"

IMAGE_DEPENDS_sdcard = "parted-native:do_populate_sysroot \
                        dosfstools-native:do_populate_sysroot \
                        mtools-native:do_populate_sysroot \
                        virtual/kernel:do_deploy \
                        arndale-bootlets:do_install \
                        ${@d.getVar('IMAGE_BOOTLOADER', True) and d.getVar('IMAGE_BOOTLOADER', True) + ':do_deploy' or ''}"

SDCARD = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.sdcard"

SDCARD_GENERATION_COMMAND_arndale= "generate_arndale_sdcard"

generate_arndale_sdcard () {
	# Create partition table
    parted -s ${SDCARD} mklabel msdos
    # Create boot partition and mark it as bootable
    # Create boot partition and mark it as bootable
    parted -s ${SDCARD} unit KiB mkpart primary fat16 ${IMAGE_ROOTFS_ALIGNMENT} $(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT})
    #parted -s ${SDCARD} set 1 boot on
    # Create rootfs partition to the end of disk
    parted -s ${SDCARD} -- unit KiB mkpart primary ext2 $(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT}) -1s
    parted ${SDCARD} print
                            
	case "${IMAGE_BOOTLOADER}" in
		u-boot)
            dd if=${DEPLOY_DIR_IMAGE}/arndale-bl1.bin of=${SDCARD} conv=notrunc bs=512 seek=${UBOOT_B1_POS}
            dd if=${DEPLOY_DIR_IMAGE}/${SPL_BINARY} of=${SDCARD} conv=notrunc bs=512 seek=${UBOOT_B2_POS}
            dd if=${DEPLOY_DIR_IMAGE}/u-boot.${UBOOT_SUFFIX} of=${SDCARD} conv=notrunc bs=512 seek=${UBOOT_BIN_POS}
            dd if=/dev/zero of=${SDCARD} seek=${UBOOT_ENV_POS} conv=notrunc count=32 bs=512
		;;

		*)
		bberror "Unknown IMAGE_BOOTLOADER value"
		exit 1
		;;
	esac

    # create Boot partition
    BOOT_BLOCKS=$(LC_ALL=C parted -s ${SDCARD} unit b print \
        | awk '/ 1 / { print substr($4, 1, length($4 -1)) / 1024 }')
    echo "boot.img blocks ${BOOT_BLOCKS}"

    mkfs.vfat -n "BOOT" -S 512 -C ${WORKDIR}/boot.img ${BOOT_BLOCKS}

    mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${MACHINE}.bin ::/${KERNEL_IMAGETYPE}
    mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${KERNEL_DEVICETREE} ::/${KERNEL_DEVICETREE}
    mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/boot.ini ::/uEnv.txt

    # Burn Partitions
    dd if=${WORKDIR}/boot.img of=${SDCARD} conv=notrunc seek=1 bs=$(expr ${IMAGE_ROOTFS_ALIGNMENT} \* 1024) && sync && sync
    dd if=${SDIMG_ROOTFS} of=${SDCARD} conv=notrunc seek=1 bs=$(expr 1024 \* ${BOOT_SPACE_ALIGNED} + ${IMAGE_ROOTFS_ALIGNMENT} \* 1024) && sync && sync
}

IMAGE_CMD_sdcard () {
	if [ -z "${SDCARD_ROOTFS}" ]; then
		bberror "SDCARD_ROOTFS is undefined. To use sdcard image from Arndale BSP it needs to be defined."
		exit 1
	fi

    # Align partitions
    BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
    BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE_ALIGNED} - ${BOOT_SPACE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})
    ROOTFS_SIZE=`du -bks ${SDIMG_ROOTFS} | awk '{print $1}'`
    # Round up RootFS size to the alignment size as well
    ROOTFS_SIZE_ALIGNED=$(expr ${ROOTFS_SIZE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
    ROOTFS_SIZE_ALIGNED=$(expr ${ROOTFS_SIZE_ALIGNED} - ${ROOTFS_SIZE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})
    SDIMG_SIZE=$(expr ${IMAGE_ROOTFS_ALIGNMENT} + ${BOOT_SPACE_ALIGNED} + ${ROOTFS_SIZE_ALIGNED})

    echo "Creating filesystem with Boot partition ${BOOT_SPACE_ALIGNED} KiB and RootFS ${ROOTFS_SIZE_ALIGNED} KiB"
    echo "Creating filesystem total size ${SDIMG_SIZE} KiB"

    # Initialize sdcard image file
    echo "dd if=/dev/zero of=${SDCARD} bs=1 count=0 seek=$(expr 1024 \* ${SDIMG_SIZE})"
    dd if=/dev/zero of=${SDCARD} bs=1 count=0 seek=$(expr 1024 \* ${SDIMG_SIZE})

	${SDCARD_GENERATION_COMMAND}
}

# The sdcard requires the rootfs filesystem to be built before using
# it so we must make this dependency explicit.
IMAGE_TYPEDEP_sdcard = "${@d.getVar('SDCARD_ROOTFS', 1).split('.')[-1]}"
