# Author: Carl Kittelberger <icedream@icedream.pw>

QNAP_FW_FILENAME=TS-X53A_20231225-4.5.4.2627.zip
QNAP_FW_URL=https://download.qnap.com/Storage/TS-X53II/$(QNAP_FW_FILENAME)

ROOT_DIR=$(CURDIR)
FW_DIR="$(ROOT_DIR)/upload"
RELEASE="alpha"
ROOT_URL="http://qne-archive.qnap.com.tw"
URL_DIR="$(ROOT_URL)/qne"
RELEASE_JSON="$(ROOT_DIR)/Release.json"
RELEASE_QNE_JSON="$(ROOT_DIR)/QTS_FW.json"
RELEASE_QNE_ADRA_JSON="$(ROOT_DIR)/ADRA_FW.json"

#firmware xml
QTS_LIVE_UPDATE="https://update.qnap.com/QTS_FW_initialization.xml"
QTS_HERO_LIVE_UPDATE="https://update.qnap.com/QTS_HERO_FW_initialization.xml"
QTS_XML_FILE=QTS_FW.xml
QTS_HERO_XML_FILE=QTS_Hero_FW.xml

# reproduced values
JSON_ADRA_URL=http://qne-archive.qnap.com/qne/adra-firmware/stable/ADRA_FW.json
JSON_QNE_URL=http://qne-archive.qnap.com/qne/qts-firmware/stable/QTS_FW.json
JSON_URL=http://qne-archive.qnap.com/qne/updater/stable/Release.json
MODEL_NAME=TS-X53II
URL_DIR=http://qne-archive.qnap.com/qne

BZIMAGE_FILES=\
	bzImage \
	bzImage.cksum \
	bzImage.sign
INITRD_BOOT_FILES=\
	initrd.boot \
	initrd.boot.cksum \
	initrd.boot.sign
ROOTFS2_BZ_FILES=\
	rootfs2.bz \
	rootfs2.bz.cksum \
	rootfs2.bz.sign
ROOTFS_EXT_TGZ_FILES=\
	rootfs_ext.tgz \
	rootfs_ext.tgz.cksum \
	rootfs_ext.tgz.sign
QPKG_TAR_FILES=\
	qpkg.tar \
	qpkg.tar.cksum \
	qpkg.tar.sign
UIMAGE_FILES=\
	uImage \
	uImage.cksum \
	uImage.sig \
	uImage.sign
BOOT_PART_FILES=\
	$(BZIMAGE_FILES) \
	$(INITRD_BOOT_FILES) \
	$(QPKG_TAR_FILES) \
	$(ROOTFS_EXT_TGZ_FILES) \
	$(ROOTFS2_BZ_FILES)
FW_FILE_LIST=\
	$(BZIMAGE_FILES) \
	fw_info \
	fw_info.conf \
	$(INITRD_BOOT_FILES) \
	$(QPKG_TAR_FILES) \
	$(ROOTFS_EXT_TGZ_FILES) \
	$(ROOTFS2_BZ_FILES) \
	sas_fw/BIOS.img \
	sas_fw/HBA.img \
	sas_fw/NAS.img \
	sas_fw/sas_fw_update.sh \
	sas_fw/sas_fw.conf \
	$(UIMAGE_FILES)


FLASH_RFS1_SIZE=484608
FLASH_RFS1_BLOCK=484608
FLASH_RFS1_DEV_PATH=RFS1
FLASH_RFS2_DEV_PATH=RFS2
BOOTLOADER_DEV_PATH=tmp/0.img

# TODO - no idea how to reconstruct this yet, this is the first 512 bytes dumped from my own NAS
GRUBSECT_DEV_PATH=dumped/mbr.bin

CONFIG_DEV_PATH=QCONFIG

LICENSE_DEV_PATH=QLICENSE

BOOT_DEV_SECTORS=1007616
BOOT_DEV_BLOCKSIZE=512

BOOT_DEV_IMG_PATH=boot.img

ROOT_DEV_IMG_PATH=root.img

# QNAP original tools

# TODO - find a non-proprietary way to decrypt the firmware
rootfs/sbin/PC1:
	./fetch-tool.sh /sbin/PC1

# QNAP original update files

$(QTS_XML_FILE):
	curl -L '-#' -o $@ $(QTS_LIVE_UPDATE)

$(QTS_HERO_XML_FILE):
	curl -L '-#' -o $@ $(QTS_HERO_LIVE_UPDATE)

$(RELEASE_JSON):
	curl -L '-#' -o $@ $(JSON_URL)

$(QNAP_FW_FILENAME):
	curl -L '-#' -o $@ "$(QNAP_FW_URL)"

%.img: %.zip
	unzip $< $@

# TODO - verify signature (add another path arg to PC1 to extract signature)
%.img.tgz: %.img rootfs/sbin/PC1
	rootfs/sbin/PC1 d QNAPNASVERSION4 $< $@ $@.sig
	$(RM) $@.sig

$(FW_FILE_LIST): $(basename $(QNAP_FW_FILENAME)).img.tgz
	tar -xzf $< $@
	touch $@

rootfs_ext.img: rootfs_ext.tgz
	tar -xzf $< $@

rootfs2.tar: rootfs2.bz
	lzma -dkc $< >$@

# TODO - update script only sets -E nodiscard on mke2fs if IS_64BITS does not exist!
$(FLASH_RFS1_DEV_PATH): $(BOOT_PART_FILES)
	$(ROOT_DIR)/create-rfs-partition.sh \
		$@ \
		$(BOOT_DEV_BLOCKSIZE) \
		$(FLASH_RFS1_BLOCK) \
		QTS_BOOT_PART2 \
		$(ROOT_DIR) \
		-E nodiscard

# TODO - update script only sets -E nodiscard on mke2fs if IS_64BITS does not exist!
$(FLASH_RFS2_DEV_PATH): $(BOOT_PART_FILES)
	$(ROOT_DIR)/create-rfs-partition.sh \
		$@ \
		$(BOOT_DEV_BLOCKSIZE) \
		$(FLASH_RFS1_BLOCK) \
		QTS_BOOT_PART3 \
		$(ROOT_DIR) \
		-E nodiscard

$(CONFIG_DEV_PATH):
	$(ROOT_DIR)/create-config-partition.sh $@

$(LICENSE_DEV_PATH):
	$(ROOT_DIR)/create-license-partition.sh $@

$(BOOTLOADER_DEV_PATH):
	$(ROOT_DIR)/create-boot-partition.sh $@

.PHONY: rfs
rfs: $(FLASH_RFS1_DEV_PATH) $(FLASH_RFS2_DEV_PATH)

%.vmdk: %.img
	qemu-img convert -O vmdk -p $< $@

%.qcow2: %.img
	qemu-img convert -O vmdk -p $< $@

$(BOOT_DEV_IMG_PATH): $(GRUBSECT_DEV_PATH) $(BOOTLOADER_DEV_PATH) $(FLASH_RFS1_DEV_PATH) $(FLASH_RFS2_DEV_PATH) $(LICENSE_DEV_PATH) $(CONFIG_DEV_PATH) boot-partitions.txt
	dd \
		if=/dev/zero \
		of=$@ \
		bs=$(BOOT_DEV_BLOCKSIZE) \
		count=$(BOOT_DEV_SECTORS) \
		status=none
	sfdisk \
		--no-reread \
		--no-tell-kernel \
		-f \
		$@ \
		<boot-partitions.txt
	dd \
		if=$(GRUBSECT_DEV_PATH) \
		of=$@ \
		skip=0 \
		bs=1 \
		count=512 \
		conv=notrunc \
		status=none
	dd \
		if=$(BOOTLOADER_DEV_PATH) \
		of=$@ \
		bs=512 \
		seek=32 \
		conv=notrunc \
		status=none
	dd \
		if=$(FLASH_RFS1_DEV_PATH) \
		of=$@ \
		bs=512 \
		seek=4352 \
		conv=notrunc \
		status=none
	dd \
		if=$(FLASH_RFS2_DEV_PATH) \
		of=$@ \
		bs=512 \
		seek=488960 \
		conv=notrunc \
		status=none
	dd \
		if=$(LICENSE_DEV_PATH) \
		of=$@ \
		bs=512 \
		seek=973600 \
		conv=notrunc \
		status=none
	dd \
		if=$(CONFIG_DEV_PATH) \
		of=$@ \
		bs=512 \
		seek=990240 \
		conv=notrunc \
		status=none

.PHONY: clean
clean:
	$(RM) \
		$(QNAP_FW_FILENAME) \
		$(wildcard *.img) \
		$(wildcard *.img.tgz) \
		$(wildcard *.img.sig) \
		$(wildcard *.vmdk) \
		$(wildcard *.qcow2) \
		$(FW_FILE_LIST) \
		$(FLASH_RFS1_DEV_PATH) \
		$(FLASH_RFS2_DEV_PATH) \
		$(CONFIG_DEV_PATH) \
		$(LICENSE_DEV_PATH) \
		$(BOOT_DEV_PATH) \
		$(ROOT_DEV_PATH)

.PHONY: clean
clean-rfs:
	$(RM) \
		$(FLASH_RFS1_DEV_PATH) \
		$(FLASH_RFS2_DEV_PATH)
