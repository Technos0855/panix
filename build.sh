#!/usr/bin/env bash

set -euo pipefail

KERNEL_VERSION=6.12.61
KERNEL_MIRROR=https://cdn.kernel.org/pub/linux/kernel/v6.x
DIR="linux-$KERNEL_VERSION"
BUSYBOX_VERSION=1.36.1

# kernel

echo "[*] Fetching kernel sources..."
if [ -e "$DIR.tar.xz" ] && [ -e "$DIR.tar.sign" ]; then
  echo "[!] Using existing $DIR.tar.xz and .sign"
else
  echo "[-] Missing one of the files. Redownloading both..."
  rm -f "$DIR.tar.xz" "$DIR.tar.sign"
  curl -OL "$KERNEL_MIRROR/$DIR.tar.xz"
  curl -OL "$KERNEL_MIRROR/$DIR.tar.sign"
fi

echo "[*] Importing + trusting kernel maintainers' GPG keys..."
gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org

LINUS_KEY=$(gpg2 --list-keys --with-colons torvalds@kernel.org | awk -F: '/^fpr:/ {print $10; exit}')
GREGKH_KEY=$(gpg2 --list-keys --with-colons gregkh@kernel.org | awk -F: '/^fpr:/ {print $10; exit}')

gpg2 --tofu-policy good "$LINUS_KEY"
gpg2 --tofu-policy good "$GREGKH_KEY"

echo "[*] Verifying signature..."
xz -cd $DIR.tar.xz | gpg2 --trust-model tofu --verify $DIR.tar.sign - || {
  echo "[-] Signature verification failed!"
  exit 1
}

if [ -d "$DIR" ]; then
  echo "[!] Source directory '$DIR' already exists."

  if [ "$FORCE" = "1" ]; then
    echo "[!] FORCE=1, removing old source directory..."
    rm -rf "$DIR"
  else
    echo "[!] Reusing existing directory. (Set FORCE=1 to re-extract)"
  fi
fi

if [ ! -d "$DIR" ]; then
  echo "[*] Extracting kernel sources..."
  tar xf $DIR.tar.xz

  echo "[+] Patching..."
  sed -i 'N;s/WARN("missing symbol table");\n\t\treturn -1;/\n\t\treturn 0;\n\t\t\/\/ A missing symbol table is actually possible if its an empty .o file.  This can happen for thunk_64.o./g' $DIR/tools/objtool/elf.c
  sed -i 's/unsigned long __force_order/\/\/ unsigned long __force_order/g' $DIR/arch/x86/boot/compressed/pgtable_64.c

  echo "[*] Preparing kernel configuration..."
  make -C $DIR defconfig
  make -C $DIR scripts

  CFG="$DIR/scripts/config"

  $CFG --enable CONFIG_NET_9P
  $CFG --disable CONFIG_NET_9P_DEBUG
  $CFG --enable CONFIG_9P_FS
  $CFG --enable CONFIG_9P_FS_POSIX_ACL
  $CFG --enable CONFIG_9P_FS_SECURITY
  $CFG --enable CONFIG_NET_9P_VIRTIO
  $CFG --enable CONFIG_VIRTIO_PCI
  $CFG --enable CONFIG_VIRTIO_BLK
  $CFG --enable CONFIG_VIRTIO_BLK_SCSI
  $CFG --enable CONFIG_VIRTIO_NET
  $CFG --enable CONFIG_VIRTIO_CONSOLE
  $CFG --enable CONFIG_HW_RANDOM_VIRTIO
  $CFG --enable CONFIG_DRM_VIRTIO_GPU
  $CFG --enable CONFIG_VIRTIO_PCI_LEGACY
  $CFG --enable CONFIG_VIRTIO_BALLOON
  $CFG --enable CONFIG_VIRTIO_INPUT
  $CFG --enable CONFIG_CRYPTO_DEV_VIRTIO
  $CFG --enable CONFIG_BALLOON_COMPACTION
  $CFG --enable CONFIG_PCI
  $CFG --enable CONFIG_PCI_HOST_GENERIC
  $CFG --enable CONFIG_GDB_SCRIPTS
  $CFG --enable CONFIG_DEBUG_INFO
  $CFG --disable CONFIG_DEBUG_INFO_REDUCED
  $CFG --disable CONFIG_DEBUG_INFO_SPLIT
  $CFG --enable CONFIG_DEBUG_FS
  $CFG --enable CONFIG_FRAME_POINTER
  $CFG --enable CONFIG_DEBUG_INFO_DWARF4
  $CFG --enable CONFIG_DEBUG_INFO_BTF
  $CFG --enable CONFIG_DEBUG_INFO_COMPRESSED_NONE
  $CFG --disable CONFIG_DEBUG_INFO_COMPRESSED_ZLIB
  $CFG --disable CONFIG_DEBUG_INFO_COMPRESSED_ZSTD
  $CFG --enable CONFIG_PRINTK
  $CFG --enable CONFIG_KALLSYMS
  $CFG --enable CONFIG_KALLSYMS_ALL
  $CFG --enable CONFIG_MODULES
  $CFG --enable CONFIG_MODULE_UNLOAD
  $CFG --enable CONFIG_MODULES_TREE_LOOKUP

  make -C $DIR olddefconfig

  echo "[+] Building kernel..."
  make -C $DIR -j"$(nproc)" bzImage
  make -C $DIR -j"$(nproc)" modules
  make -C $DIR modules_install INSTALL_MOD_PATH=./fs
fi

# busybox

echo "[*] Downloading busybox..."
curl -OL https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2

[ -e busybox-$BUSYBOX_VERSION ] || tar xjf busybox-$BUSYBOX_VERSION.tar.bz2

echo "[*] Building busybox..."
make -C busybox-$BUSYBOX_VERSION defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/g' busybox-$BUSYBOX_VERSION/.config
# disable tc (fix build errors on modern kernels)
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' busybox-$BUSYBOX_VERSION/.config
make -C busybox-$BUSYBOX_VERSION -j"$(nproc)"
make -C busybox-$BUSYBOX_VERSION install

# filesystem

echo "[*] Building filesystem..."
cd fs
mkdir -p bin sbin etc proc sys usr/bin usr/sbin root home/panix
cd ..
cp -a busybox-$BUSYBOX_VERSION/_install/* fs

# modules

echo "[+] Building modules..."
cd src
make
cd ..
cp src/*.ko fs/
