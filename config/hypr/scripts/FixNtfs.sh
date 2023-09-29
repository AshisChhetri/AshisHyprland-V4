#!/bin/bash

sudo umount /dev/sda2 &&
sudo ntfsfix /dev/sda2
sudo mount /dev/sda2

sudo umount /dev/sda4 &&
sudo ntfsfix /dev/sda4
sudo mount /dev/sda4

sudo ntfsfix /dev/nvme0n1p5 &&
sudo ntfsfix /dev/nvme0n1p5
sudo mount /dev/nvme0n1p5

sudo ntfsfix /dev/nvme0n1p6 &&
sudo ntfsfix /dev/nvme0n1p6
sudo mount /dev/nvme0n1p6
