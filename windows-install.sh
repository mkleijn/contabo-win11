#!/bin/bash

# Windows 11 ISO download URL
# Get the direct download link from: https://www.microsoft.com/en-us/software-download/windows11
# Select "Download Windows 11 Disk Image (ISO)" -> Windows 11 -> your language -> 64-bit Download
# Then pass the URL as the first argument to this script, or set WIN11_ISO_URL.
WIN11_ISO_URL="${1:-${WIN11_ISO_URL:-}}"

if [ -z "$WIN11_ISO_URL" ]; then
    echo "ERROR: No Windows 11 ISO URL provided."
    echo "Usage: ./windows-install.sh '<ISO_DOWNLOAD_URL>'"
    echo ""
    echo "Get the download link from: https://www.microsoft.com/en-us/software-download/windows11"
    echo "1. Scroll to 'Download Windows 11 Disk Image (ISO) for x64 devices'"
    echo "2. Select 'Windows 11 (multi-edition ISO for x64 devices)' and click Download"
    echo "3. Choose your language and click Confirm"
    echo "4. Click the '64-bit Download' button and copy the URL"
    echo "5. Run: ./windows-install.sh '<PASTE_URL_HERE>'"
    exit 1
fi

apt update -y && apt upgrade -y

apt install grub2 wimtools ntfs-3g -y

#Get the disk size in GB and convert to MB
disk_size_gb=$(parted /dev/sda --script print | awk '/^Disk \/dev\/sda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))

#Calculate partition size (25% of total size)
part_size_mb=$((disk_size_mb / 4))

#Create GPT partition table
parted /dev/sda --script -- mklabel gpt

#Create two partitions
parted /dev/sda --script -- mkpart primary ntfs 1MB ${part_size_mb}MB
parted /dev/sda --script -- mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

#Inform kernel of partition table changes
partprobe /dev/sda

sleep 30

partprobe /dev/sda

sleep 30

partprobe /dev/sda

sleep 30 

#Format the partitions
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2

echo "NTFS partitions created"

echo -e "r\ng\np\nw\nY\n" | gdisk /dev/sda

mount /dev/sda1 /mnt

#Prepare directory for the Windows disk
cd ~
mkdir windisk

mount /dev/sda2 windisk

grub-install --root-directory=/mnt /dev/sda

#Edit GRUB configuration
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "windows installer" {
	insmod ntfs
	search --set=root --file=/bootmgr
	ntldr /bootmgr
	boot
}
EOF

cd /root/windisk
mkdir winfile

wget -O win11.iso "$WIN11_ISO_URL"

mount -o loop win11.iso winfile

rsync -avz --progress winfile/* /mnt

umount winfile

wget -O virtio.iso https://shorturl.at/lsOU3

mount -o loop virtio.iso winfile

mkdir /mnt/sources/virtio

rsync -avz --progress winfile/* /mnt/sources/virtio

cd /mnt/sources

touch cmd.txt

echo 'add virtio /virtio_drivers' >> cmd.txt

wimlib-imagex update boot.wim 2 < cmd.txt

reboot


