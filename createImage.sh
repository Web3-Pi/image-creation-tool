#!/bin/bash
#
# Web3 Pi .img creation tool v.0.1.2
#

# Function to display help message
function display_help {
    echo
    echo "Bash script to generate a Web3 Pi image (.img) based on Ubuntu for Raspberry Pi"
    echo
    echo "Usage: sudo ./createImage.sh [MODE] [BRANCH] [OUTPUT_FILE_NAME]"
    echo
    echo "Parameters:"
    echo "  MODE   : One of 'single', 'exec', or 'consensus'. (Required)"
    echo "  BRANCH : Branch name from the repository https://github.com/Web3-Pi/Ethereum-On-Raspberry-Pi (e.g., 'r0.7.1'). (Required)"
    echo "  OUTPUT_FILE_NAME : Name of the file where the generated image will be saved. (Required)"
    echo
    echo "Options:"
    echo "  -?     : Display this help message."
    echo
    echo "Example:"
    echo "  sudo ./createImage.sh single r0.7.1 Web3Pi_Single_Device.img"
    echo
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)" >&2
    exit 1
fi

# Check for help flag
if [ "$1" == "-?" ]; then
    display_help
    exit 0
fi

# Check that we have exactly three arguments
if [ $# -ne 3 ]; then
    echo "Error: Incorrect number of arguments." >&2
    display_help
    exit 1
fi

# Assigning arguments to variables
MODE=$1
BRANCH=$2
OUTPUT_FILE_NAME=$3

# Validate MODE parameter
if [[ "$MODE" != "single" && "$MODE" != "exec" && "$MODE" != "consensus" ]]; then
    echo "Error: Invalid MODE. Must be one of 'single', 'exec', or 'consensus'." >&2
    display_help
    exit 1
fi

# Validate BRANCH parameter (simple check)
if [[ -z "$BRANCH" ]]; then
    echo "Error: BRANCH cannot be empty." >&2
    display_help
    exit 1
fi

# Validate OUTPUT_FILE_NAME (simple check)
if [[ -z "$OUTPUT_FILE_NAME" ]]; then
    echo "Error: OUTPUT_FILE_NAME cannot be empty." >&2
    display_help
    exit 1
fi

# If all validations pass, proceed with the script logic
echo 
echo "Generating Web3 Pi image with MODE: $MODE, BRANCH: $BRANCH, and saving to: $OUTPUT_FILE_NAME"

# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
echo 
echo "Script dir = $SCRIPT_DIR"

# Create working dirs
mkdir -p $SCRIPT_DIR/output
mkdir -p $SCRIPT_DIR/tmp

# Install required software
apt-get update
apt-get install -y git git-extras qemu-utils kpartx

# Download official Ubuntu image for Raspberry Pi
if [ -f "$SCRIPT_DIR/tmp/ubuntu-24.04.1-preinstalled-server-arm64+raspi.img.xz" ]; then
  echo ".img.xz file allready exist."
else
  echo "Downloading..."
  wget https://cdimage.ubuntu.com/releases/24.04.1/release/ubuntu-24.04.1-preinstalled-server-arm64+raspi.img.xz -P $SCRIPT_DIR/tmp
fi

# Decompress .img.xz to .img
if [ -f "$SCRIPT_DIR/tmp/ubuntu-24.04.1-preinstalled-server-arm64+raspi.img" ]; then
  echo ".img file allready exist. Deleting ubuntu-24.04.1-preinstalled-server-arm64+raspi.img"
  rm $SCRIPT_DIR/tmp/ubuntu-24.04.1-preinstalled-server-arm64+raspi.img
fi
echo "Decompressing..."
xz --decompress -k -f -v $SCRIPT_DIR/tmp/ubuntu-24.04.1-preinstalled-server-arm64+raspi.img.xz

echo 
echo "ls -lh $SCRIPT_DIR/tmp/"
ls -lh $SCRIPT_DIR/tmp/

echo 
sudo modprobe nbd
sudo modprobe nbd max_part=16
lsmod | grep nbd
sudo chown root:disk /dev/nbd0
sudo qemu-nbd --disconnect /dev/nbd0

# Attach the image
sudo qemu-nbd --format=raw --connect=/dev/nbd0 "$SCRIPT_DIR/tmp/ubuntu-24.04.1-preinstalled-server-arm64+raspi.img"

# Check which partitions are available on the nbd0 device
sudo fdisk -l /dev/nbd0

# Mount the boot partition
sudo mkdir -p /mnt/boot
sudo mount /dev/nbd0p1 /mnt/boot

echo 
echo "ls -lh /mnt/boot"
ls -lh /mnt/boot

# Mount the root partition
sudo mkdir -p /mnt/root
sudo mount /dev/nbd0p2 /mnt/root

echo 
echo "ls -lh /mnt/root"
ls -lh /mnt/root


echo 
mkdir -p /mnt/root/opt/web3pi

git-force-clone --branch ${BRANCH} https://github.com/Web3-Pi/Ethereum-On-Raspberry-Pi.git /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi
git-force-clone https://github.com/Web3-Pi/basic-system-monitor.git /mnt/root/opt/web3pi/basic-system-monitor
git-force-clone https://github.com/Web3-Pi/basic-eth2-node-monitor.git /mnt/root/opt/web3pi/basic-eth2-node-monitor

cp /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi/distros/raspberry_pi/rc.local /mnt/root/etc/rc.local
chmod +x /mnt/root/etc/rc.local

echo
if [ "$MODE" = "consensus" ]; then
  echo "MODE consensus"
  cp /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi/distros/raspberry_pi/config-consensus.txt /mnt/boot/config.txt
elif [ "$MODE" = "exec" ]; then
  echo "MODE exec"
  cp /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi/distros/raspberry_pi/config-exec.txt /mnt/boot/config.txt
else
  echo "MODE single"
  cp /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi/distros/raspberry_pi/config.txt /mnt/boot/config.txt
fi

echo
mkdir -p /mnt/root/opt/web3pi/influxdb
wget -P /mnt/root/opt/web3pi/influxdb https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_arm64.deb

echo
# pieeprom-2024-06-05.bin is with our config file
cp $SCRIPT_DIR/fw/2712/pieeprom-2024-06-05.bin /mnt/root/lib/firmware/raspberrypi/bootloader-2712/default/
cp $SCRIPT_DIR/fw/2711/pieeprom-2024-04-15.bin /mnt/root/lib/firmware/raspberrypi/bootloader-2711/default/


# check
echo
ls /mnt/root/opt/web3pi/influxdb
echo
ls /mnt/root/lib/firmware/raspberrypi/bootloader-2712/default/
echo

mv -f $SCRIPT_DIR/tmp/ubuntu-24.04.1-preinstalled-server-arm64+raspi.img $SCRIPT_DIR/output/$OUTPUT_FILE_NAME

echo
# Umount partitions
sudo umount /mnt/boot
sudo umount /mnt/root
# Disconnect image/device
sudo qemu-nbd --disconnect /dev/nbd0

echo
echo "Done! Modified image .img file is in output dir"
echo
exit 0
