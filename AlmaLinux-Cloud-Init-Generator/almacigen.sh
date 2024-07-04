#!/bin/bash

# AlmaLinux Cloud Init generator
# for Headless installation
#
# This script *sometimes* require administrative privilege
#
# This script will do the following:
# 1. Configure Alma Linux's "user-data" such as
#    username, password, current machine public
#    SSH key(s), etc
# 2. Generating proper "user-data" file for boot
#
# Usage     : bash almacigen.sh
#
# (c) 2024. David Eleazar

# Global variables
STUB_FILE=$(pwd)/stubs/user-data.stub
FINAL_FILE=$(pwd)/user-data
CURR_MACHINE_TZ=$(timedatectl | grep "Time zone" | awk -F" " {'print $3'})
CURR_USER=$(logname)
DEFAULT_HOSTNAME=almalinux
CURR_USER_SSH_DIR=$HOME/.ssh
GLOBAL_SSH_DIR=/etc/ssh
PREGENERATED_SSH_DIR=./ssh

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

function install_dependencies() {
    if [[ ! -z $(which dnf) ]]; then
        PM=dnf
    elif [[ ! -z $(which apt) ]]; then
        PM=apt
    else
        echo -e "${YELLOW}No supported package manager found.${NC}"
    fi


    if [[ "$PM" == "dnf" ]]; then
        INSTALLED=$($PM list installed | grep mkpasswd)
    else
        INSTALLED=$($PM list --installed | grep mkpasswd)
    fi

    if [[ "$INSTALLED" == "" ]]; then
        sudo $PM install mkpasswd -y
    fi
}

function input_user_data() {
    # username
    read -p "Username : " USERNAME
    if [[ "$USERNAME" == "" ]]; then
        USERNAME=$CURR_USER
        echo -e "${YELLOW}No username entered. Will use ${LBLUE}$USERNAME${YELLOW} as username.${NC}"
    fi

    # password
    read -s -p "Password : " PLAIN_PWD
    echo
    read -s -p "Confirm Password : " PLAIN_PWD_CONF
    echo

    if [[ "$PLAIN_PWD" != "$PLAIN_PWD_CONF" ]]; then
        echo -e "${LRED}Password mismatch! Exiting . . .${NC}"
        exit 1
    elif [[ "$PLAIN_PWD" == "" ]]; then
        echo -e "${LRED}Password cannot be empty! Exiting . . .${NC}"
        exit 1
    else
        echo -e "${LGREEN}Password match.${NC}"
        PASSWORD=$(mkpasswd -m sha-512 "$PLAIN_PWD")
    fi

    # enable SSH password login
    read -p "Enable SSH password login? (y/[n]) : " SSH_PWD_LOGIN
    if [[ "${SSH_PWD_LOGIN,,}" == "y" || "${SSH_PWD_LOGIN,,}" == "yes" ]]; then
        SSH_PWD_LOGIN=true
        SSH_PWD_LOGIN_STATUS=enabled
        SSH_PWD_COLOR=$YELLOW
    else
        SSH_PWD_LOGIN=false
        SSH_PWD_LOGIN_STATUS=disabled
        SSH_PWD_COLOR=$LBLUE
    fi

    # hostname
    read -p "Hostname  : " HOSTNAME
    if [[ "$HOSTNAME" == "" ]]; then
        HOSTNAME=$DEFAULT_HOSTNAME
        echo -e "${YELLOW}No hostname entered. Will use ${LBLUE}$HOSTNAME${YELLOW} as hostname.${NC}"
    fi

    # timezone
    TIMEZONE=$CURR_MACHINE_TZ

    # enable WiFi connection
    read -p "Enable WiFi connection? (y/[n]) : " WIFI_CONN_ENABLE
    if [[ "${WIFI_CONN_ENABLE,,}" == "y" || "${WIFI_CONN_ENABLE,,}" == "yes" ]]; then
        read -p "WiFi SSID : " WIFI_SSID
        read -s -p "WiFi Password : " WIFI_PWD

        # optional: enable static MAC
        echo
        read -p "Optional: Using static MAC address for WiFi? (y/[n]) : " WIFI_STATIC_MAC_ENABLE
        if [[ "${WIFI_STATIC_MAC_ENABLE,,}" == "y" || "${WIFI_STATIC_MAC_ENABLE,,}" == "yes" ]]; then
            read -p "WiFi MAC Address : " WIFI_MAC
        fi
    fi

    # preview
    echo
    echo -e "${WHITE}##### Preview #####${NC}"
    echo -e "${LGREEN}Username is ${LBLUE}$USERNAME${NC}"
    echo -e "${LGREEN}Password is ${LBLUE}$PLAIN_PWD${NC}"
    echo -e "${LGREEN}Hostname is ${LBLUE}$HOSTNAME${NC}"
    echo -e "${LGREEN}Timezone is ${LBLUE}$TIMEZONE${NC}"
    echo -e "${LGREEN}SSH password login will be ${SSH_PWD_COLOR}$SSH_PWD_LOGIN_STATUS.${NC}"
    
    if [[ "${WIFI_CONN_ENABLE,,}" == "y" || "${WIFI_CONN_ENABLE,,}" == "yes" ]]; then
        echo -e "${LGREEN}WiFi connection is ${LBLUE}enabled${NC}."
        echo -e "${LCYAN} -> SSID       : ${WHITE}$WIFI_SSID${NC}"
        echo -e "${LCYAN} -> Password   : ${WHITE}$WIFI_PWD${NC}"
        if [[ "${WIFI_STATIC_MAC_ENABLE,,}" == "y" || "${WIFI_STATIC_MAC_ENABLE,,}" == "yes" ]]; then
            echo -e "${LCYAN} -> Static MAC : ${WHITE}$WIFI_MAC${NC}"
        fi
    else
        echo -e "${LGREEN}WiFi connection is ${YELLOW}disabled${NC}."
    fi

    read -p "Proceed? ([y], n) : " PROCEED
    if [[ "${PROCEED,,}" == "n" || "${PROCEED,,}" == "no" ]]; then
        exit 0
    fi
}

function get_indent_space_length_from_file() {
    local FILE=$1
    local PATTERN=$2

    IFS=""
    local STRING=$(cat $FILE | grep "$PATTERN")
    local SPACE_LENGTH=$(expr match "$STRING" " *")

    echo $SPACE_LENGTH
}

function get_curr_machine_pub_ssh_keys() {
    local SPACE_LENGTH=$(get_indent_space_length_from_file $STUB_FILE "<public_ssh_key_placeholder>")

    if [[ -d "$CURR_USER_SSH_DIR" ]]; then
        echo -e "${LGREEN}Using public SSH keys from ${LPURPLE}$CURR_USER_SSH_DIR.${NC}"

        declare -a SSH_KEY_LIST=($(ls $CURR_USER_SSH_DIR | grep ".pub"))
        for i in "${SSH_KEY_LIST[@]}"; do
            CONTENT=$(cat "$CURR_USER_SSH_DIR/$i")
            PUBLIC_KEY=$(printf "%${SPACE_LENGTH}s- ${CONTENT}")
            PUB_KEY_LIST="${PUB_KEY_LIST}${PUBLIC_KEY}\n"
        done
    elif [[ ! -d "$CURR_USER_SSH_DIR" && "$(ls $GLOBAL_SSH_DIR/*.pub 2>/dev/null)" != "" ]]; then
        echo -e "${LGREEN}Using public SSH keys from ${LPURPLE}$GLOBAL_SSH_DIR.${NC}"

        declare -a SSH_KEY_LIST=($(ls $GLOBAL_SSH_DIR | grep ".pub"))
        for i in "${SSH_KEY_LIST[@]}"; do
            CONTENT=$(sudo cat "$GLOBAL_SSH_DIR/$i")
            PUBLIC_KEY=$(printf "%${SPACE_LENGTH}s- ${CONTENT}")
            PUB_KEY_LIST="${PUB_KEY_LIST}${PUBLIC_KEY}\n"
        done
    else
        echo -e "${YELLOW}User SSH key directory not found.${NC}"
        echo -e "${YELLOW}Global SSH key files not found.${NC}"
        echo -e "${LRED}No public SSH keys will be added to the config.${NC}"

        # set the list to empty string
        PUB_KEY_LIST=""
    fi
}

function get_pregenerated_ssh_keys() {
    local SPACE_LENGTH=$(get_indent_space_length_from_file $STUB_FILE "<pregenerated_ssh_keys_placeholder>")

    SSH_KEYS=""

    if [[ -d "$PREGENERATED_SSH_DIR" ]]; then

        # get the public keys first to determine the private keys and key type
        declare -a PREGEN_SSH_KEYS=($(ls $PREGENERATED_SSH_DIR | grep ".pub"))

        for i in "${PREGEN_SSH_KEYS[@]}"; do
            # handling private SSH key
            PRIV_KEY_FILE=$(echo $i | awk -F. {'print $1'})
            PRIV_KEY_CONTENT=""
            
            # adding leading spaces to the private key content
            while IFS="" read -r line
            do
                SPACE_LINE=$(printf "%$((SPACE_LENGTH + 2))s$line\\n")
                PRIV_KEY_CONTENT=$(printf "%s$PRIV_KEY_CONTENT\n$SPACE_LINE")
            done < $PREGENERATED_SSH_DIR/$PRIV_KEY_FILE

            # handling public SSH key content
            PUB_KEY_CONTENT=$(cat "$PREGENERATED_SSH_DIR/$i")
            RAW_ALGO=$(echo $PUB_KEY_CONTENT | awk -F' ' {'print $1'})

            # algorithm determination
            if [[ "$(echo $RAW_ALGO | grep rsa)" != "" ]]; then
                ALGO=rsa
            elif [[ "$(echo $RAW_ALGO | grep ecdsa)" != "" ]]; then
                ALGO=ecdsa
            elif [[ "$(echo $RAW_ALGO | grep ed25519)" != "" ]]; then
                ALGO=ed25519
            else
                ALGO=unknown
            fi
            
            PRIV_LABEL="${ALGO}_private: |"
            PUB_LABEL="${ALGO}_public: "
            MERGED_PRIV_KEY=$(printf "%${SPACE_LENGTH}s${PRIV_LABEL}${PRIV_KEY_CONTENT}")
            MERGED_PUB_KEY=$(printf "%${SPACE_LENGTH}s${PUB_LABEL}${PUB_KEY_CONTENT}")
            MERGED_KEY=$(printf "${MERGED_PRIV_KEY}\n$MERGED_PUB_KEY")

            if [[ "$SSH_KEYS" == "" ]]; then
                SSH_KEYS=$(printf "${SSH_KEYS}${MERGED_KEY}")
            else
                SSH_KEYS=$(printf "${SSH_KEYS}\n${MERGED_KEY}")
            fi
        done
    fi
}

function build_config() {
    echo -e "Loading config stub file . . ."
    if [[ ! -f "$STUB_FILE" ]]; then
        echo -e "${LRED}Missing config stub file. Might be possibly deleted. Re-clone this repo and re-run this script.${NC}"
        exit 2
    fi
    cp $STUB_FILE $FINAL_FILE

    echo -e "Building configuration . . ."
    # for regular data, just replace the placeholder with designated value
    awk -v old="<add_your_hostname_here>" -v new="$HOSTNAME" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE
    awk -v old="<enable_password_auth_ssh>" -v new="$SSH_PWD_LOGIN" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE
    awk -v old="<add_your_user_here>" -v new="$USERNAME" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE
    awk -v old="<add_your_password_here>" -v new="$PASSWORD" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE
    awk -v old="<add_your_timezone_here>" -v new="$TIMEZONE" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE

    # SSH key listing require special care
    if [[ "$PUB_KEY_LIST" != "" ]]; then
        # delete the SSH key placeholder first, then get the 'ssh_authorized_keys:' position
        sed -i '/<public_ssh_key_placeholder>/d' $FINAL_FILE
        awk -v old="ssh_authorized_keys:" -v new="ssh_authorized_keys:\n${PUB_KEY_LIST}" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE
    else
        # No user or machine SSH key found
        sed -i "/<public_ssh_key_placeholder>/d" $FINAL_FILE
        sed -i "/ssh_authorized_keys/d" $FINAL_FILE
    fi

    if [[ "$SSH_KEYS" != "" ]]; then
        IFS=""

        # delete the SSH key placeholder first, then get the 'ssh_keys:' position
        echo -e "${LGREEN}Pre-generated SSH key(s) found at $PREGENERATED_SSH_DIR.${NC}"
        echo -e "${WHITE}Will use them as target machine's SSH key(s).${NC}"
        
        sed -i "/<pregenerated_ssh_keys_placeholder>/d" $FINAL_FILE
        awk -v old="ssh_keys:" -v new="ssh_keys:\n${SSH_KEYS}" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE
    else
        # No pregenerated SSH key found
        echo -e "${LRED}No pre-generated SSH key(s) found at $PREGENERATED_SSH_DIR.${NC}"
        sed -i "/<pregenerated_ssh_keys_placeholder>/d" $FINAL_FILE
        sed -i "/ssh_keys/d" $FINAL_FILE
    fi

    if [[ "${WIFI_CONN_ENABLE,,}" == "y" || "${WIFI_CONN_ENABLE,,}" == "yes" ]]; then
        awk -v old="<add_your_wifi_ssid_here>" -v new="${WIFI_SSID}" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE
        awk -v old="<add_your_wifi_pwd_here>" -v new="${WIFI_PWD}" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE

        # set the WiFi MAC address
        if [[ "${WIFI_STATIC_MAC_ENABLE,,}" == "y" || "${WIFI_STATIC_MAC_ENABLE,,}" == "yes" ]]; then
            awk -v old="<add_your_static_mac_here>" -v new="${WIFI_MAC}" '{gsub(old,new);print}' $FINAL_FILE > tmp && mv tmp $FINAL_FILE
        else
            sed -i "/nmcli con/d" $FINAL_FILE
        fi
    else
        sed -i "/nmcli dev wifi/d" $FINAL_FILE
        sed -i "/nmcli con/d" $FINAL_FILE
    fi

    echo -e "\n${LCYAN}Configuration file created.${NC}"
}

# Execution flow here
install_dependencies
input_user_data
get_curr_machine_pub_ssh_keys
get_pregenerated_ssh_keys
build_config
