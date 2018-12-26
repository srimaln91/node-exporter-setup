#!/bin/bash

#Run as a root user
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (with sudo command)"
  exit
fi

#Colours
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\033[0m' # No Color

# Build architecture
ARCH=linux-amd64

# Locate required binaries
YUM_CMD=$(which yum)
APT_GET_CMD=$(which apt-get)
TAR_BIN=$(which tar)
WGET_BIN=$(which wget)

#Universal package installer function
install_package() {

    if [[ ! -z $YUM_CMD ]]; then
        yum update -y
        yum install -y $1
    elif [[ ! -z $APT_GET_CMD ]]; then
        apt-get update -y
        apt-get install -y $1
    else
        echo "error can't install package $1"
        exit 1;
    fi

}

# Filter out wget progress bar
progressfilter ()
{
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%c' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
}


# Install wget if it is not installed
if ! [ -x "$(command -v wget)" ]; then
  printf "${GREEN}Installing wget\n${NC}"
  install_package wget
fi


# Filter out the required download link from github API response
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep "browser_download_url" | grep $ARCH | cut -d '"' -f 4)

TEMP_DIR=/tmp/node_exporter_temp
rm -rf $TEMP_DIR && mkdir $TEMP_DIR

OUT_FILENAME=node_exporter.tar.gz
NE_DIR=/opt/node_exporter

# Download the latest release
$WGET_BIN --progress=bar:force $DOWNLOAD_URL  -O $TEMP_DIR/$OUT_FILENAME 2>&1 | progressfilter
$TAR_BIN -xvf $TEMP_DIR/$OUT_FILENAME -C $TEMP_DIR/

# Move all files to /opt directory
rm -rf $TEMP_DIR/$OUT_FILENAME
mkdir $NE_DIR
cp -r $TEMP_DIR/node_exporter*/* $NE_DIR/

# Create a symlink to the real binary file in system binaries
ln -s $NE_DIR/node_exporter /bin/node_exporter

# Clean temporary files
rm -rf $TEMP_DIR

printf "${GREEN}Installed binary files\n${NC}"

# Create systemd service file
cat <<EOF > /etc/systemd/system/node-exporter.service
[Unit]
Description=Expose node metrics for the prometheus consumption
After=network.target
Wants=network.target

[Service]
Type=simple
Restart=always
RestartSec=1
ExecStart=/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon and enable suto start
systemctl daemon-reload

printf "${GREEN}Created systemd service\n${NC}"

# All done
printf "${GREEN}Installation is successful.\n${NC}"

# start service
systemctl start node-exporter
printf "${GREEN}Started the service.\n${NC}"

# Start service on system startup
systemctl enable node-exporter
printf "${GREEN}Enabled automatic startup.\n${NC}"

printf "${GREEN}Installation is completed! :)\n${NC}"
printf "You can use ${YELLOW}systemctl {start|stop|restart} node-exporter${NC} command to control the service\n"
