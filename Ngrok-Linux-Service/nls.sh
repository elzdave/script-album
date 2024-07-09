#!/bin/bash

# Ngrok Linux Service installer
#
# This script require administrative privilege
#
# This script will do the following:
# 1. Configure Ngrok's YAML required data such as
#    authentication token, domain, tunnel(s)
# 2. Determine which Ngrok binary to download
#    based on detected system architecture
# 3. Install and enable Ngrok service to
#    autostart on system boot
#
# Usage     : sudo bash nls.sh
#
# (c) 2023. David Eleazar

# Global variables
CURRENT_USER=$(logname)
NGROK_DIR=/usr/local/bin
NGROK_CONFIG_DIR=$(getent passwd $(logname) | cut -d: -f6)/.config/ngrok
SERVICE_DIR=/etc/systemd/system
STUB_DIR=stubs
NGROK_EXAMPLE_CONF=${STUB_DIR}/ngrok.yml.example

# ANSI colors
NC='\033[0m'
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BROWN='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LGRAY='\033[0;37m'
DGRAY='\033[1;30m'
LRED='\033[1;31m'
LGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LBLUE='\033[1;34m'
LPURPLE='\033[1;35m'
LCYAN='\033[1;36m'
WHITE='\033[1;37m'

function sanity_check() {
    echo -e "${WHITE}Sanity checking . . .${NC}"

    if [ ! $(which wget) ]; then
        echo -e "${LRED}ERROR: 'wget' not found. Please install it first and re-execute this script.${NC}"
        exit 1
    fi

    if [ "$(id -u)" != "0" ];then
        echo -e "${WHITE}Usage: sudo bash nls.sh${NC}"
        echo -e "_____"
        echo -e "${LRED}ERROR: Root access denied. Please run as root.${NC}"
        exit 1
    fi

    echo -e "${LGREEN}Environment is sane.${NC}"
}

function get_arch() {
    local UNAME=$(uname -m)
    local BIT=$(getconf LONG_BIT)
    local ARCH=

    if [[ $UNAME == x86_64* ]]; then
        ARCH=amd64
    elif [[ $UNAME == i*86 ]]; then
        ARCH=386
    elif [[ $UNAME == aarch64* || $UNAME == armv* ]]; then
        if [[ $BIT == 64 ]]; then
            ARCH=arm64
        else
            ARCH=arm
        fi
    elif [[ $UNAME == s390* ]]; then
        ARCH=s390x
    else
        # return the printed 'uname -m' as architecture name
        ARCH=$UNAME
    fi

    # return the result
    echo $ARCH
}

function download_and_extract_bin() {
    local ARCH=$(get_arch)
    local TGZ="ngrok-v3-stable-linux-$ARCH.tgz"
    local DOWNLOAD_URL="https://bin.equinox.io/c/bNyj1mQVY4c/$TGZ"

    echo -e "Downloading ${WHITE}Ngrok${NC} for ${CYAN}$ARCH${NC} to ${LGREEN}$NGROK_DIR${NC}"
    wget $DOWNLOAD_URL -O $NGROK_DIR/$TGZ

    # Check whether file is successfully downloaded
    if [ ! -f "$NGROK_DIR/$TGZ" ]; then
        echo -e "${LRED}ERROR: Downloaded archive ${LPURPLE}$TGZ${LRED} not found. Exiting . . .${NC}"
        exit 1
    fi

    echo -e "Extracting downloaded ${LPURPLE}$TGZ${NC} file inside ${LGREEN}$NGROK_DIR${NC} . . ."
    tar -xzf $NGROK_DIR/$TGZ -C $NGROK_DIR

    echo -e "Enabling ${WHITE}Ngrok${NC}'s execute flag . . ."
    chmod +x $NGROK_DIR/ngrok

    echo -e "Deleting unused ${LPURPLE}$TGZ${NC} file . . ."
    rm -f $NGROK_DIR/$TGZ
}

function build_config() {
    echo -e "Preparing ${WHITE}Ngrok${NC}'s configuration file . . ."
    if [ ! -d "$NGROK_CONFIG_DIR" ]; then
        echo -e "Creating Ngrok's config directory at ${LGREEN}$NGROK_CONFIG_DIR${NC}"
        mkdir $NGROK_CONFIG_DIR -p
    fi
    cp $NGROK_EXAMPLE_CONF $NGROK_CONFIG_DIR/ngrok.yml

    echo
    read -p "Enter Authtoken : " AUTHTOKEN
    sed -i "s/<add_your_token_here>/$AUTHTOKEN/g" $NGROK_CONFIG_DIR/ngrok.yml

    read -p "Enter Web tunnel domain (leave blank if none) : " WEB_DOMAIN
    if [ "$WEB_DOMAIN" != "" ]; then
        sed -i "s/<web_domain>/\"$WEB_DOMAIN\"/g" $NGROK_CONFIG_DIR/ngrok.yml
    else
        sed -i "/<web_domain>/d" $NGROK_CONFIG_DIR/ngrok.yml
    fi

    read -p "Enter targeted Web port (leave blank to use default port 80) : " WEB_PORT
    if [ "$WEB_PORT" != "" ]; then
        sed -i "s/<web_port>/$WEB_PORT/g" $NGROK_CONFIG_DIR/ngrok.yml
    else
        sed -i "s/<web_port>/80/g" $NGROK_CONFIG_DIR/ngrok.yml
    fi

    read -p "Enter SSH tunnel domain (leave blank if none) : " SSH_DOMAIN
    if [ "$SSH_DOMAIN" != "" ]; then
        sed -i "s/<ssh_domain>/\"$SSH_DOMAIN\"/g" $NGROK_CONFIG_DIR/ngrok.yml
    else
        sed -i "/<ssh_domain>/d" $NGROK_CONFIG_DIR/ngrok.yml
    fi

    read -p "Enter SSH tunnel port (leave blank to use default port 22) : " SSH_PORT
    if [ "$SSH_PORT" != "" ]; then
        sed -i "s/<ssh_port>/$SSH_PORT/g" $NGROK_CONFIG_DIR/ngrok.yml
    else
        sed -i "s/<ssh_port>/22/g" $NGROK_CONFIG_DIR/ngrok.yml
    fi

    echo -e "Setting owner of ${LGREEN}$NGROK_CONFIG_DIR${NC}"
    chown $CURRENT_USER:$CURRENT_USER $NGROK_CONFIG_DIR -R

    echo -e "${LCYAN}Configuration file created.${NC}"
}

function enable_service() {
    echo -e "Enabling ${WHITE}Ngrok${NC}'s service . . ."
    $NGROK_DIR/ngrok service install --config=$NGROK_CONFIG_DIR/ngrok.yml
    $NGROK_DIR/ngrok service start
}

function disable_service() {
    echo -e "Disabling ${WHITE}Ngrok${NC}'s service . . ."
    $NGROK_DIR/ngrok service stop
    $NGROK_DIR/ngrok service uninstall
}

function delete_resources() {
    echo -e "Deleting ${WHITE}Ngrok${NC}'s resources . . ."
    rm -rf $NGROK_DIR
    rm -rf $NGROK_CONFIG_DIR
}

function install() {
    echo -e "Installing ${WHITE}Ngrok${NC} . . ."
    mkdir -p $NGROK_DIR
    download_and_extract_bin
    build_config
    enable_service
    echo -e "${LBLUE}Done installing Ngrok.${NC}"
}

function uninstall() {
    echo -e "Uninstalling ${WHITE}Ngrok${NC} . . ."
    disable_service
    delete_resources
    echo -e "${LBLUE}Done uninstalling Ngrok.${NC}"
}

function update() {
    if [[ ! -f "$NGROK_DIR/ngrok" ]]; then
        echo -e "${LRED}ERROR: ${WHITE}$NGROK_DIR/ngrok${LRED} not found. Exiting . . .${NC}"
        exit 1
    fi

    echo -e "Updating ${WHITE}Ngrok${NC} . . ."
    echo -e "Before update version is ${YELLOW}$(ngrok -v | awk -F' ' '{print $3}')${NC}"
    ngrok update --config $NGROK_CONFIG_DIR/ngrok.yml
    echo -e "After update version is ${YELLOW}$(ngrok -v | awk -F' ' '{print $3}')${NC}"
    echo -e "${LBLUE}Done updating Ngrok.${NC}"
}

function main() {
    sanity_check

    local MODE=install

    echo "Select mode :"
    select opts in "Install" "Update" "Uninstall"; do
        case $opts in
            Install) MODE=install; break;;
            Update) MODE=update; break;;
            Uninstall) MODE=uninstall; break;;
            *) echo "Invalid option $opts";;
        esac
    done

    if [ "$MODE" == "install" ]; then
        install
    elif [ "$MODE" == "update" ]; then
        update
    else
        uninstall
    fi

    exit 0
}

# Execute main function
main
