#!/bin/sh

sudo dd if=/dev/zero of=/encrypted-swap count=0 bs=1G seek=1
sudo losetup /dev/loop0 /encrypted-swap

KEY="$(head --bytes 100 /dev/urandom)"
echo "$KEY" | sudo cryptsetup --batch-mode luksFormat -s 256 /dev/loop0 -d -
echo "$KEY" | sudo cryptsetup --batch-mode luksOpen /dev/loop0 fun -d -

sudo swapoff -a
sudo mkswap /dev/mapper/fun
sudo swapon /dev/mapper/fun
