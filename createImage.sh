#!/bin/bash
#
# Web3Pi .img creation tool
#

# check for required privileges
if [ "$EUID" -ne 0 ]
  then echo "Root privileges are required. Re-run as root."
  exit 1
fi

WEB3PI_DIR="/opt/web3pi"
DEV_DIR="${WEB3PI_DIR}/ubuntu_img"
FILES_PATH="${WEB3PI_DIR}/Ethereum-On-Raspberry-Pi/distros/raspberry_pi"
MODE=$1
BRANCH=$2

echo "par 1 MODE=${MODE}"
echo "par 2 BRANCH=${BRANCH}"


download_image() {
  mkdir -p $DEV_DIR
  
  if [ -f "$DEV_DIR/ubuntu-24.04-preinstalled-server-arm64+raspi.img.xz" ]; then
    echo ".img.xz file allready exist."
  else
    echo "Downloading..."
    wget https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04-preinstalled-server-arm64+raspi.img.xz -P $DEV_DIR
  fi
  
  if [ -f "$DEV_DIR/ubuntu-24.04-preinstalled-server-arm64+raspi.img" ]; then
    echo ".img file allready exist."
	rm $DEV_DIR/ubuntu-24.04-preinstalled-server-arm64+raspi.img
	xz --decompress -k -f -v ${DEV_DIR}/ubuntu-24.04-preinstalled-server-arm64+raspi.img.xz
  else
    echo "Decompressing..."
    xz --decompress -k -f -v ${DEV_DIR}/ubuntu-24.04-preinstalled-server-arm64+raspi.img.xz
  fi
   
  echo "download_image() - done"
}

clone_Web3Pi_repo_local() {
  mkdir -p $DEV_DIR
  
  git-force-clone --branch ${BRANCH} https://github.com/Web3-Pi/Ethereum-On-Raspberry-Pi.git ${WEB3PI_DIR}/Ethereum-On-Raspberry-Pi
  
  echo "clone_Web3Pi_repo_local() - done"
}

clone_Web3Pi_repos_img() {
  mkdir -p ${DEV_DIR}/img2/opt/web3pi
  
  git-force-clone --branch ${BRANCH} https://github.com/Web3-Pi/Ethereum-On-Raspberry-Pi.git ${DEV_DIR}/img2/opt/web3pi/Ethereum-On-Raspberry-Pi
  
  git-force-clone https://github.com/Web3-Pi/basic-system-monitor.git ${DEV_DIR}/img2/opt/web3pi/basic-system-monitor
   
  git-force-clone https://github.com/Web3-Pi/basic-eth2-node-monitor.git ${DEV_DIR}/img2/opt/web3pi/basic-eth2-node-monitor
  
  echo "clone_Web3Pi_repos_img() - done"
}

prepare_image() {
  # https://github.com/novamostra/mountpi/blob/main/mountpi.sh

  mkdir -p ${DEV_DIR}/img1
  mkdir -p ${DEV_DIR}/img2
  
  IMG_LOOP=$(losetup --find --partscan --show ${DEV_DIR}/ubuntu-24.04-preinstalled-server-arm64+raspi.img)
  echo "$IMG_LOOP"
  #Partition with config.txt
  mount ${IMG_LOOP}p1 -o rw ${DEV_DIR}/img1
  #Main partition 
  mount ${IMG_LOOP}p2 -o rw ${DEV_DIR}/img2
  
  #mount -o loop,offset=537919488 /tmp/dev/ubuntu_img/ubuntu-24.04-preinstalled-server-arm64+raspi.img /tmp/dev/ubuntu_img/img2
  
  cp ${FILES_PATH}/rc.local ${DEV_DIR}/img2/etc/rc.local
  chmod +x ${DEV_DIR}/img2/etc/rc.local
  
  
	if [ "$MODE" = "consensus" ]; then
	  echo "MODE consensus"
	  cp ${FILES_PATH}/config-consensus.txt ${DEV_DIR}/img1/config.txt
	elif [ "$MODE" = "exec" ]; then
	  echo "MODE exec"
	  cp ${FILES_PATH}/config-exec.txt ${DEV_DIR}/img1/config.txt
	else
	  echo "MODE single"
	  cp ${FILES_PATH}/config.txt ${DEV_DIR}/img1/config.txt
	fi
  
  echo "prepare_image() - done"
}

apt-get -y install git-extras

download_image

clone_Web3Pi_repo_local

prepare_image

clone_Web3Pi_repos_img

mkdir -p ${DEV_DIR}/img2/opt/web3pi/influxdb
wget -P ${DEV_DIR}/img2/opt/web3pi/influxdb https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_arm64.deb

#pieeprom-2024-06-05.bin is with our config file
cp fw/2712/pieeprom-2024-06-05.bin ${DEV_DIR}/img2/lib/firmware/raspberrypi/bootloader-2712/default/
cp fw/2711/pieeprom-2024-04-15.bin ${DEV_DIR}/img2/lib/firmware/raspberrypi/bootloader-2711/default/

umount /opt/web3pi/ubuntu_img/img2
umount /opt/web3pi/ubuntu_img/img1
