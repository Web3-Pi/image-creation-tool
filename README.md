# image-creation-tool

Bash script to generate a Web3Pi image (.img) based on Ubuntu 24.04 for Raspberry Pi 4 and Raspberry Pi 5

## Use

Clone repository

```shell
sudo apt-get -y install git
git clone https://github.com/Web3-Pi/image-creation-tool
```

Prepare to use

```shell
cd image-creation-tool
chmod +x createImage.sh
```

Run

```shell
sudo ./create_service.sh single r3
```

Param one is mode: single, exec or consensus.  
Param two is branch name of https://github.com/Web3-Pi/Ethereum-On-Raspberry-Pi repository.

Output file is in: `/opt/web3pi/ubuntu_img/ubuntu-24.04-preinstalled-server-arm64+raspi.img`