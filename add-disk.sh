sudo fdisk /dev/vdb
sudo mkfs -t ext4 /dev/vdb1 &&
sudo tune2fs -m 1 /dev/vdb1