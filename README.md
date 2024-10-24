# image-creation-tool

Bash script to generate a Web3Pi image (.img) based on Ubuntu 24.04.1 for Raspberry Pi.

## Use

Clone repository

```shell
git clone https://github.com/Web3-Pi/image-creation-tool
```

Prepare to use

```shell
cd image-creation-tool
chmod +x createImage.sh 
```

Run

```shell
sudo ./createImage.sh single r0.7.1
```

Param one is mode: single, exec or consensus.  
Param two is branch name of https://github.com/Web3-Pi/Ethereum-On-Raspberry-Pi repository.

**single** - Single device mode: execusion, consensus clients and monitoring   
**exec** - Dual devices mode: excution client   
**consensus** - Dual devices mode: consensus client

Output file is in `image-creation-tool/output` directory.