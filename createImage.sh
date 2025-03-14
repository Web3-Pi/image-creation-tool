#!/bin/bash
#
# Web3 Pi .img creation tool
#

# Function to display help message
function display_help {
    echo
    echo "Bash script to generate a Web3 Pi image (.img) based on Ubuntu for Raspberry Pi"
    echo
    echo "Usage: sudo ./createImage.sh [MODE] [BRANCH]"
    echo
    echo "Parameters:"
    echo "  MODE   : One of 'single', 'exec', or 'consensus'. (Required)"
    echo "  BRANCH : Branch name from the repository https://github.com/Web3-Pi/Ethereum-On-Raspberry-Pi (e.g., 'r0.7.1'). (Required)"
    echo
    echo "Options:"
    echo "  -?     : Display this help message."
    echo
    echo "Example:"
    echo "  sudo ./createImage.sh single r0.7.1"
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

# Check that we have exactly two arguments
if [ $# -ne 2 ]; then
    echo "Error: Incorrect number of arguments." >&2
    display_help
    exit 1
fi

# Assigning arguments to variables
MODE=$1
BRANCH=$2

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



# If all validations pass, proceed with the script logic
echo 
echo "Generating Web3 Pi image with MODE: $MODE, BRANCH: $BRANCH"

# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
echo 
echo "Script dir = $SCRIPT_DIR"

# Create working dirs
mkdir -p $SCRIPT_DIR/output
mkdir -p $SCRIPT_DIR/tmp

# Install required software
#apt-get update
#apt-get install -y git qemu-utils kpartx unzip

# Download official Ubuntu image for Raspberry Pi
if [ -f "$SCRIPT_DIR/tmp/ubuntu-24.04.2-preinstalled-server-arm64+raspi.img.xz" ]; then
  echo ".img.xz file allready exist."
else
  echo "Downloading..."
  wget https://cdimage.ubuntu.com/releases/24.04.2/release/ubuntu-24.04.2-preinstalled-server-arm64+raspi.img.xz -P $SCRIPT_DIR/tmp
fi

# Decompress .img.xz to .img
if [ -f "$SCRIPT_DIR/tmp/ubuntu-24.04.2-preinstalled-server-arm64+raspi.img" ]; then
  echo ".img file allready exist. Deleting ubuntu-24.04.2-preinstalled-server-arm64+raspi.img"
  rm $SCRIPT_DIR/tmp/ubuntu-24.04.2-preinstalled-server-arm64+raspi.img
fi
echo "Decompressing..."
xz --decompress -k -f -v $SCRIPT_DIR/tmp/ubuntu-24.04.2-preinstalled-server-arm64+raspi.img.xz

echo 
echo "ls -lh $SCRIPT_DIR/tmp/"
ls -lh $SCRIPT_DIR/tmp/

echo 
modprobe nbd
modprobe nbd max_part=16
lsmod | grep nbd
chown root:disk /dev/nbd0
qemu-nbd --disconnect /dev/nbd0

# Attach the image
qemu-nbd --format=raw --connect=/dev/nbd0 "$SCRIPT_DIR/tmp/ubuntu-24.04.2-preinstalled-server-arm64+raspi.img"

# Check which partitions are available on the nbd0 device
fdisk -l /dev/nbd0

# Mount the boot partition
mkdir -p /mnt/boot
mount /dev/nbd0p1 /mnt/boot

echo 
echo "ls -lh /mnt/boot"
ls -lh /mnt/boot

# Mount the root partition
mkdir -p /mnt/root
mount /dev/nbd0p2 /mnt/root

echo 
echo "ls -lh /mnt/root"
ls -lh /mnt/root


echo 
mkdir -p /mnt/root/opt/web3pi

git clone -b ${BRANCH} https://github.com/Web3-Pi/Ethereum-On-Raspberry-Pi.git /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi
git clone https://github.com/Web3-Pi/basic-system-monitor.git /mnt/root/opt/web3pi/basic-system-monitor
git clone https://github.com/Web3-Pi/basic-eth2-node-monitor.git /mnt/root/opt/web3pi/basic-eth2-node-monitor

cp /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi/distros/raspberry_pi/rc.local /mnt/root/etc/rc.local
chmod +x /mnt/root/etc/rc.local


echo
OUTPUT_FILE_NAME="Web3Pi_image.img"
if [ "$MODE" = "consensus" ]; then
  echo "MODE consensus"
  OUTPUT_FILE_NAME="Web3Pi_Dual_Devices_Consensus.img"
  cp /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi/distros/raspberry_pi/config-consensus.txt /mnt/boot/config.txt
elif [ "$MODE" = "exec" ]; then
  echo "MODE exec"
  OUTPUT_FILE_NAME="Web3Pi_Dual_Devices_Execution.img"
  cp /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi/distros/raspberry_pi/config-exec.txt /mnt/boot/config.txt
else
  echo "MODE single"
  OUTPUT_FILE_NAME="Web3Pi_Single_Device.img"
  cp /mnt/root/opt/web3pi/Ethereum-On-Raspberry-Pi/distros/raspberry_pi/config.txt /mnt/boot/config.txt
fi

echo
mkdir -p /mnt/root/opt/web3pi/influxdb
wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_arm64.deb -P /mnt/root/opt/web3pi/influxdb

echo
# pieeprom-2024-06-05.bin is with our config file
#rm /mnt/root/lib/firmware/raspberrypi/bootloader-2712/default/pieeprom-*
cp $SCRIPT_DIR/fw/2712/pieeprom-2025-01-13-w3p.bin /mnt/root/opt/web3pi/pieeprom-2025-01-13-w3p.bin

# disable rpi-eeprom-update.service
unlink /mnt/root/etc/systemd/system/multi-user.target.wants/rpi-eeprom-update.service

# Disable unattended-upgrades.service 
unlink /mnt/root/etc/systemd/system/multi-user.target.wants/unattended-upgrades.service 

# rm $SCRIPT_DIR/tmp/web3-pi-dashboard-bin.zip
wget https://github.com/Web3-Pi/web3-pi-dashboard/releases/latest/download/web3-pi-dashboard-bin.zip -O $SCRIPT_DIR/tmp/web3-pi-dashboard-bin.zip
unzip $SCRIPT_DIR/tmp/web3-pi-dashboard-bin.zip -d /mnt/root/opt/web3pi/

chmod +x /mnt/root/opt/web3pi/web3-pi-dashboard-bin/hwmonitor

echo
echo "ls -lh /mnt/root/opt/web3pi"
ls -lh /mnt/root/opt/web3pi

echo
echo "ls -lh /mnt/root/opt/web3pi/influxdb"
ls -lh /mnt/root/opt/web3pi/influxdb

# Create the service file for web3-pi-dashboard
cp $SCRIPT_DIR/files/w3p_lcd.service /mnt/root/etc/systemd/system/w3p_lcd.service

# Activate the service – To ensure the service starts on boot, create a symbolic link in the appropriate directory.
ln -s /mnt/root/etc/systemd/system/w3p_lcd.service /mnt/root/etc/systemd/system/multi-user.target.wants/w3p_lcd.service

# MOTD update
cp $SCRIPT_DIR/files/00-header /mnt/root/etc/update-motd.d/00-header
cp $SCRIPT_DIR/files/10-help-text /mnt/root/etc/update-motd.d/10-help-text
chmod +x /mnt/root/etc/update-motd.d/00-header
chmod +x /mnt/root/etc/update-motd.d/10-help-text

# installation-status
# copy binnary app
mkdir /mnt/root/opt/web3pi/installation-status
wget https://github.com/Web3-Pi/installation-status/releases/latest/download/app -O /mnt/root/opt/web3pi/installation-status/installation-status-app
#cp $SCRIPT_DIR/files/installation-status-app /mnt/root/opt/web3pi/installation-status/installation-status-app
chmod +x /mnt/root/opt/web3pi/installation-status/installation-status-app
# Create the service file for installation-status
cp $SCRIPT_DIR/files/w3p_installation-status.service /mnt/root/etc/systemd/system/w3p_installation-status.service
# Activate the service – To ensure the service starts on boot, create a symbolic link in the appropriate directory.
ln -s /mnt/root/etc/systemd/system/w3p_installation-status.service /mnt/root/etc/systemd/system/multi-user.target.wants/w3p_installation-status.service



# Delete default user-data file
rm /mnt/boot/user-data

# Copy our user-data file to boot partition
cp $SCRIPT_DIR/files/user-data /mnt/boot/

# Save the branch name from which this image was built.
echo "$BRANCH" > /mnt/root/opt/web3pi/version.txt

echo
# Umount partitions
umount /mnt/boot
umount /mnt/root
# Disconnect image/device
qemu-nbd --disconnect /dev/nbd0


# Delete the previously created file if exist
if [ -f "$SCRIPT_DIR/output/$OUTPUT_FILE_NAME" ]; then
  echo
  echo "$SCRIPT_DIR/output/$OUTPUT_FILE_NAME file allready exist. Deleting..."
  rm $SCRIPT_DIR/output/$OUTPUT_FILE_NAME
fi
# Move ready file to output dir
mv -f $SCRIPT_DIR/tmp/ubuntu-24.04.2-preinstalled-server-arm64+raspi.img $SCRIPT_DIR/output/$OUTPUT_FILE_NAME

echo
echo "Done! Modified image .img file is in output dir"
echo "$SCRIPT_DIR/output/$OUTPUT_FILE_NAME"
echo
exit 0
