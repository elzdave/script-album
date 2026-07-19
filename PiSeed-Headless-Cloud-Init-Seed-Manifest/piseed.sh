#!/bin/bash

# =====================================================================
# piseed.sh : Headless Cloud-Init Manifest Generator for Raspberry Pi
# =====================================================================
# Description       : Generates user-data, meta-data, and network-config
#                     files for automating Raspberry Pi setups running
#                     AlmaLinux or Raspberry Pi OS.
# Style Standard    : Google Bash Scripting Guide
# Usage             : bash piseed.sh
# Author            : David Eleazar
# Year              : 2024 - 2026
# =====================================================================

# --- System Execution Environment ---
set -o pipefail

# --- Path Configurations ---
SCRIPT_EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Global Constants ---
readonly FINAL_FILE="${SCRIPT_EXEC_DIR}/user-data"
readonly META_FILE="${SCRIPT_EXEC_DIR}/meta-data"
readonly NET_FILE="${SCRIPT_EXEC_DIR}/network-config"
readonly CONFIG_PROFILE="${SCRIPT_EXEC_DIR}/data.own"
readonly PREGENERATED_SSH_DIR="${SCRIPT_EXEC_DIR}/ssh"
readonly GLOBAL_SSH_DIR="/etc/ssh"
readonly DEFAULT_HOSTNAME="raspberrypi"

# --- Host Environment Defaults ---
HOST_MACHINE_TZ="$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}')"
readonly SYSTEM_TIMEZONE="${HOST_MACHINE_TZ:-UTC}"

HOST_LOGGED_USER="$(logname 2>/dev/null || echo "pi")"
readonly TARGET_DEFAULT_USER="${HOST_LOGGED_USER}"
readonly CURR_USER_SSH_DIR="${HOME}/.ssh"

# --- ANSI Terminal Colors ---
readonly COLOR_NC='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_LBLUE='\033[1;34m'
readonly COLOR_LCYAN='\033[1;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_LPURPLE='\033[1;35m'

# --- Global Configuration Variables ---
GEN_USERNAME=""
GEN_PASSWORD_HASH=""
GEN_PLAIN_PWD=""
GEN_SSH_PWD_LOGIN="false"
GEN_SSH_PWD_STATUS="disabled"
GEN_SSH_PWD_COLOR="${COLOR_LBLUE}"
GEN_SSH_PORT="default"
GEN_HOSTNAME=""
GEN_WIFI_CONN_ENABLE="false"
GEN_WIFI_SSID=""
GEN_WIFI_PWD=""
GEN_WIFI_STATIC_MAC_ENABLE="false"
GEN_WIFI_MAC=""
GEN_WIFI_REG_DOMAIN="GB"
GEN_ENABLE_REBOOT="false"
AGGREGATED_PUB_KEY_LIST=""
AGGREGATED_HOST_SSH_KEYS=""

# =====================================================================
# Function: install_dependencies
# Description: Checks and installs 'mkpasswd' if missing.
# =====================================================================
install_dependencies() {
    if command -v mkpasswd >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${COLOR_YELLOW}[*] 'mkpasswd' utility not found. Installing via package manager...${COLOR_NC}"
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y expect || sudo dnf install -y mkpasswd
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y expect || sudo yum install -y mkpasswd
    elif command -v apt-get >/dev/null 2>&1 || command -v apt >/dev/null 2>&1; then
        sudo apt-get update -y && sudo apt-get install -y whois
    else
        echo -e "${COLOR_RED}ERROR: Unsupported host environment. Please install 'mkpasswd' manually.${COLOR_NC}"
        exit 1
    fi
}

# =====================================================================
# Function: load_from_config_profile
# Description: Parses the 'data.own' key-value file line-by-line.
# =====================================================================
load_from_config_profile() {
    echo -e "${COLOR_GREEN}[+] Local configuration profile 'data.own' detected. Importing variables...${COLOR_NC}"
    
    local key=""
    local value=""

    while IFS='=' read -r key value || [[ -n "${key}" ]]; do
        # Trim leading and trailing whitespaces from key
        key="${key#${key%%[![:space:]]*}}"
        key="${key%${key##*[![:space:]]}}"
        
        # Skip comments and empty lines
        [[ -z "${key}" || "${key}" == "#"* ]] && continue
        
        # Strip inline comments preceded by a space
        if [[ "${value}" == *" #"* ]]; then
            value="${value%% #*}"
        fi
        
        # Trim whitespace from value
        value="${value#${value%%[![:space:]]*}}"
        value="${value%${value##*[![:space:]]}}"
        
        # Strip wrapping quotes
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        case "${key}" in
            USERNAME) GEN_USERNAME="${value}" ;;
            PASSWORD) 
                GEN_PLAIN_PWD="${value}"
                GEN_PASSWORD_HASH="$(mkpasswd -m sha-512 "${value}")"
                ;;
            SSH_PASSWORD_LOGIN) 
                if [[ "${value,,}" == "true" || "${value,,}" == "y" || "${value,,}" == "yes" ]]; then
                    GEN_SSH_PWD_LOGIN="true"
                    GEN_SSH_PWD_STATUS="enabled"
                    GEN_SSH_PWD_COLOR="${COLOR_YELLOW}"
                else
                    GEN_SSH_PWD_LOGIN="false"
                    GEN_SSH_PWD_STATUS="disabled"
                    GEN_SSH_PWD_COLOR="${COLOR_LBLUE}"
                fi
                ;;
            SSH_PORT) GEN_SSH_PORT="${value}" ;;
            HOSTNAME) GEN_HOSTNAME="${value}" ;;
            WIFI_ENABLE) GEN_WIFI_CONN_ENABLE="${value}" ;;
            WIFI_SSID) GEN_WIFI_SSID="${value}" ;;
            WIFI_PASSWORD) GEN_WIFI_PWD="${value}" ;;
            WIFI_REG_DOMAIN) GEN_WIFI_REG_DOMAIN="${value}" ;;
            WIFI_STATIC_MAC_ENABLE) GEN_WIFI_STATIC_MAC_ENABLE="${value}" ;;
            WIFI_MAC) GEN_WIFI_MAC="${value}" ;;
            ENABLE_REBOOT) GEN_ENABLE_REBOOT="${value}" ;;
        esac
    done < "${CONFIG_PROFILE}"

    # Apply default hostname if empty
    if [[ -z "${GEN_HOSTNAME}" ]]; then
        GEN_HOSTNAME="${DEFAULT_HOSTNAME}"
        echo -e "${COLOR_YELLOW}[*] Hostname omitted in profile. Defaulting to: ${COLOR_LBLUE}${GEN_HOSTNAME}${COLOR_NC}"
    fi

    # Validate required fields
    if [[ -z "${GEN_USERNAME}" || -z "${GEN_PLAIN_PWD}" ]]; then
        echo -e "${COLOR_RED}ERROR: 'data.own' is missing required fields (USERNAME, PASSWORD).${COLOR_NC}"
        exit 3
    fi
}

# =====================================================================
# Function: input_user_data
# Description: Collects user configuration interactively from terminal.
# =====================================================================
input_user_data() {
    local input_username=""
    local plain_pwd_first=""
    local plain_pwd_conf=""
    local input_ssh_pwd_login=""
    local input_ssh_port_chg=""
    local input_hostname=""
    local input_wifi_conn_enable=""
    local input_wifi_static_mac_enable=""
    local input_wifi_reg=""

    read -p "Username : " input_username
    if [[ -z "${input_username}" ]]; then
        GEN_USERNAME="${TARGET_DEFAULT_USER}"
        echo -e "${COLOR_YELLOW}No username entered. Defaulting to: ${COLOR_LBLUE}${GEN_USERNAME}${COLOR_NC}"
    else
        GEN_USERNAME="${input_username}"
    fi

    while true; do
        read -s -p "Password : " plain_pwd_first
        echo
        read -s -p "Confirm Password : " plain_pwd_conf
        echo
        if [[ "${plain_pwd_first}" != "${plain_pwd_conf}" ]]; then
            echo -e "${COLOR_RED}Password mismatch! Try again.${COLOR_NC}"
        elif [[ -z "${plain_pwd_first}" ]]; then
            echo -e "${COLOR_RED}Password cannot be empty! Try again.${COLOR_NC}"
        else
            echo -e "${COLOR_GREEN}Password saved.${COLOR_NC}"
            GEN_PLAIN_PWD="${plain_pwd_first}"
            GEN_PASSWORD_HASH="$(mkpasswd -m sha-512 "${plain_pwd_first}")"
            break
        fi
    done

    read -p "Enable SSH password login? (y/[n]) : " input_ssh_pwd_login
    if [[ "${input_ssh_pwd_login,,}" == "y" || "${input_ssh_pwd_login,,}" == "yes" ]]; then
        GEN_SSH_PWD_LOGIN="true"
        GEN_SSH_PWD_STATUS="enabled"
        GEN_SSH_PWD_COLOR="${COLOR_YELLOW}"
    else
        GEN_SSH_PWD_LOGIN="false"
        GEN_SSH_PWD_STATUS="disabled"
        GEN_SSH_PWD_COLOR="${COLOR_LBLUE}"
    fi

    read -p "Change SSH port? (y/[n]) : " input_ssh_port_chg
    if [[ "${input_ssh_port_chg,,}" == "y" || "${input_ssh_port_chg,,}" == "yes" ]]; then
        read -p "Enter desired SSH port : " GEN_SSH_PORT
    else
        GEN_SSH_PORT="default"
    fi

    read -p "Hostname : " input_hostname
    if [[ -z "${input_hostname}" ]]; then
        GEN_HOSTNAME="${DEFAULT_HOSTNAME}"
        echo -e "${COLOR_YELLOW}No hostname entered. Defaulting to: ${COLOR_LBLUE}${GEN_HOSTNAME}${COLOR_NC}"
    else
        GEN_HOSTNAME="${input_hostname}"
    fi

    read -p "Enable WiFi connection? (y/[n]) : " input_wifi_conn_enable
    GEN_WIFI_CONN_ENABLE="${input_wifi_conn_enable}"
    if [[ "${input_wifi_conn_enable,,}" == "y" || "${input_wifi_conn_enable,,}" == "yes" || "${input_wifi_conn_enable,,}" == "true" ]]; then
        read -p "WiFi SSID : " GEN_WIFI_SSID
        read -s -p "WiFi Password : " GEN_WIFI_PWD
        echo
        read -p "WiFi Regulatory Domain (e.g., SG, GB, ID, US) [GB] : " input_wifi_reg
        GEN_WIFI_REG_DOMAIN="${input_wifi_reg:-GB}"
        read -p "Optional: Use static MAC address for WiFi? (y/[n]) : " input_wifi_static_mac_enable
        GEN_WIFI_STATIC_MAC_ENABLE="${input_wifi_static_mac_enable}"
        if [[ "${input_wifi_static_mac_enable,,}" == "y" || "${input_wifi_static_mac_enable,,}" == "yes" || "${input_wifi_static_mac_enable,,}" == "true" ]]; then
            read -p "WiFi MAC Address : " GEN_WIFI_MAC
        fi
    fi

    read -p "Enable system reboot? (Recommended) (y/[n]) : " GEN_ENABLE_REBOOT
}

# =====================================================================
# Function: acquire_target_configuration
# Description: Loads configuration from profile file or interactive prompt.
# =====================================================================
acquire_target_configuration() {
    if [[ -f "${CONFIG_PROFILE}" ]]; then
        load_from_config_profile
    else
        input_user_data
    fi
}

# =====================================================================
# Function: verify_and_confirm_preview
# Description: Displays configuration preview for user verification.
# =====================================================================
verify_and_confirm_preview() {
    echo
    echo -e "${COLOR_WHITE}##### Preview #####${COLOR_NC}"
    echo -e "${COLOR_GREEN}Username is ${COLOR_LBLUE}${GEN_USERNAME}${COLOR_NC}"
    echo -e "${COLOR_GREEN}Password is ${COLOR_LBLUE}${GEN_PLAIN_PWD}${COLOR_NC}"
    echo -e "${COLOR_GREEN}Hostname is ${COLOR_LBLUE}${GEN_HOSTNAME}${COLOR_NC}"
    echo -e "${COLOR_GREEN}Timezone is ${COLOR_LBLUE}${SYSTEM_TIMEZONE}${COLOR_NC}"
    echo -e "${COLOR_GREEN}SSH password login will be ${GEN_SSH_PWD_COLOR}${GEN_SSH_PWD_STATUS}.${COLOR_NC}"
    
    if [[ "${GEN_SSH_PORT}" != "default" ]]; then
        echo -e "${COLOR_GREEN}SSH port is ${COLOR_WHITE}${GEN_SSH_PORT}.${COLOR_NC}"
    else
        echo -e "${COLOR_GREEN}SSH port is ${COLOR_WHITE}22 (default).${COLOR_NC}"
    fi

    if [[ "${GEN_WIFI_CONN_ENABLE,,}" == "y" || "${GEN_WIFI_CONN_ENABLE,,}" == "yes" || "${GEN_WIFI_CONN_ENABLE,,}" == "true" ]]; then
        echo -e "${COLOR_GREEN}WiFi connection is ${COLOR_LBLUE}enabled${COLOR_NC}."
        echo -e "${COLOR_LCYAN} -> SSID       : ${COLOR_WHITE}${GEN_WIFI_SSID}${COLOR_NC}"
        echo -e "${COLOR_LCYAN} -> Password   : ${COLOR_WHITE}${GEN_WIFI_PWD}${COLOR_NC}"
        echo -e "${COLOR_LCYAN} -> Reg Domain : ${COLOR_WHITE}${GEN_WIFI_REG_DOMAIN}${COLOR_NC}"
        if [[ "${GEN_WIFI_STATIC_MAC_ENABLE,,}" == "y" || "${GEN_WIFI_STATIC_MAC_ENABLE,,}" == "yes" || "${GEN_WIFI_STATIC_MAC_ENABLE,,}" == "true" ]]; then
            echo -e "${COLOR_LCYAN} -> Static MAC : ${COLOR_WHITE}${GEN_WIFI_MAC}${COLOR_NC}"
        fi
    else
        echo -e "${COLOR_GREEN}WiFi connection is ${COLOR_YELLOW}disabled${COLOR_NC}."
    fi

    if [[ "${GEN_ENABLE_REBOOT,,}" == "y" || "${GEN_ENABLE_REBOOT,,}" == "yes" || "${GEN_ENABLE_REBOOT,,}" == "true" ]]; then
        echo -e "${COLOR_YELLOW}System will reboot after initialization setup finishes."
        echo -e "This will take a few minutes before SSH connections are accepted.${COLOR_NC}"
    else
        echo -e "${COLOR_WHITE}System will not reboot after finished initial setup."
        echo -e "${COLOR_YELLOW}Note: SELinux will temporary run in ${COLOR_GREEN}permissive${COLOR_YELLOW} mode until next reboot.${COLOR_NC}"
    fi
    echo

    local proceed_token=""
    read -p "Proceed to generate files? ([y], n) : " proceed_token
    if [[ "${proceed_token,,}" == "n" || "${proceed_token,,}" == "no" ]]; then
        echo -e "${COLOR_RED}Generation cancelled by user.${COLOR_NC}"
        exit 0
    fi
}

# =====================================================================
# Function: get_curr_machine_pub_ssh_keys
# Description: Reads available user public SSH keys from host system.
# =====================================================================
get_curr_machine_pub_ssh_keys() {
    local tmp_fmt=""
    local pub_file=""
    local content=""

    if [[ -d "${CURR_USER_SSH_DIR}" ]] && [[ -n "$(find "${CURR_USER_SSH_DIR}" -maxdepth 1 -type f -name "*.pub" -print -quit 2>/dev/null)" ]]; then
        echo -e "${COLOR_GREEN}[+] Extracting public SSH keys from ${COLOR_LPURPLE}${CURR_USER_SSH_DIR}${COLOR_NC}"
        while IFS= read -r pub_file; do
            [[ -z "${pub_file}" ]] && continue
            content="$(cat "${pub_file}")"
            printf -v tmp_fmt "      - %s\n" "${content}"
            AGGREGATED_PUB_KEY_LIST+="${tmp_fmt}"
        done < <(find "${CURR_USER_SSH_DIR}" -maxdepth 1 -type f -name "*.pub" 2>/dev/null)
        
    elif [[ -n "$(find "${GLOBAL_SSH_DIR}" -maxdepth 1 -type f -name "*.pub" -print -quit 2>/dev/null)" ]]; then
        echo -e "${COLOR_GREEN}[+] Extracting public SSH keys from ${COLOR_LPURPLE}${GLOBAL_SSH_DIR}${COLOR_NC}"
        while IFS= read -r pub_file; do
            [[ -z "${pub_file}" ]] && continue
            content="$(sudo cat "${pub_file}")"
            printf -v tmp_fmt "      - %s\n" "${content}"
            AGGREGATED_PUB_KEY_LIST+="${tmp_fmt}"
        done < <(find "${GLOBAL_SSH_DIR}" -maxdepth 1 -type f -name "*.pub" 2>/dev/null)
    else
        echo -e "${COLOR_YELLOW}[!] Warning: No public SSH keys found on host system.${COLOR_NC}"
    fi
}

# =====================================================================
# Function: get_pregenerated_ssh_keys
# Description: Reads pre-generated target host keys from local directory.
# =====================================================================
get_pregenerated_ssh_keys() {
    local tmp_fmt=""
    local pub_key_file=""
    local priv_key_file=""
    local pub_content=""
    local raw_algo=""
    local algo=""
    local file_line=""

    if [[ -d "${PREGENERATED_SSH_DIR}" ]]; then
        while IFS= read -r pub_key_file; do
            [[ -z "${pub_key_file}" ]] && continue
            priv_key_file="${pub_key_file%.pub}"
            
            if [[ ! -f "${priv_key_file}" ]]; then 
                continue 
            fi
            
            pub_content="$(cat "${pub_key_file}")"
            raw_algo="$(echo "${pub_content}" | awk '{print $1}')"
            algo="unknown"
            
            [[ "${raw_algo}" == *"rsa"* ]] && algo="rsa"
            [[ "${raw_algo}" == *"ecdsa"* ]] && algo="ecdsa"
            [[ "${raw_algo}" == *"ed25519"* ]] && algo="ed25519"
            
            if [[ "${algo}" == "unknown" ]]; then 
                continue 
            fi
            
            printf -v tmp_fmt "  %s_private: |\n" "${algo}"
            AGGREGATED_HOST_SSH_KEYS+="${tmp_fmt}"
            
            while IFS= read -r file_line || [[ -n "${file_line}" ]]; do
                printf -v tmp_fmt "    %s\n" "${file_line}"
                AGGREGATED_HOST_SSH_KEYS+="${tmp_fmt}"
            done < "${priv_key_file}"
            
            printf -v tmp_fmt "  %s_public: %s\n" "${algo}" "${pub_content}"
            AGGREGATED_HOST_SSH_KEYS+="${tmp_fmt}"
        done < <(find "${PREGENERATED_SSH_DIR}" -maxdepth 1 -type f -name "*.pub" 2>/dev/null)
    fi
}

# =====================================================================
# Function: load_raw_manifest_template
# Description: Returns the raw cloud-init cloud-config template stream.
# =====================================================================
load_raw_manifest_template() {
    cat << 'EOF'
#cloud-config
# =====================================================================
# Unified Cloud-Init Manifest Template for Raspberry Pi Hardware
# =====================================================================
# Configures AlmaLinux 9/10 and Raspberry Pi OS environments.
# Configurations apply only once at first system boot.
# Reference URL: https://cloudinit.readthedocs.io/en/latest/reference/examples.html

hostname: <TARGET_HOSTNAME>.local
ssh_pwauth: <SSH_PASSWORD_AUTH>

users:
  - name: <TARGET_USERNAME>
    groups: [adm, systemd-journal, wheel, sudo]
    lock_passwd: false
    homedir: /home/<TARGET_USERNAME>
    shell: /bin/bash
    passwd: <TARGET_PASSWORD_HASH>
    ssh_authorized_keys:
<PUBLIC_SSH_KEYS_BLOCK>
ssh_keys:
<PREGENERATED_HOST_KEYS_BLOCK>

runcmd:
  - hostnamectl hostname <TARGET_HOSTNAME> || true
  - timedatectl set-timezone <TARGET_TIMEZONE> || true
<WIFI_CONFIG_BLOCK>
  
  # Network and Package Manager Setup
  - |
    echo "[*] Waiting for internet access before provisioning..."
    for i in {1..30};
    do
      if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || curl -k -s -I https://1.1.1.1 >/dev/null 2>&1; then
        echo "[+] Internet detected. Syncing system repositories..."
        if command -v dnf >/dev/null 2>&1; then 
          dnf install policycoreutils-python-utils NetworkManager-wifi -y || true;
        elif command -v yum >/dev/null 2>&1; then 
          yum install policycoreutils-python-utils NetworkManager-wifi -y || true;
        elif command -v apt-get >/dev/null 2>&1; then
          apt-get update -y && apt-get install -y python3-policycoreutils policycoreutils gawk ufw network-manager || true;
        fi
        break
      fi
      sleep 1
    done

  # OpenSSH Service Hardening
  - sed -i 's/\#\?LoginGraceTime .\+/LoginGraceTime 1m/' /etc/ssh/sshd_config || true
  - sed -i 's/\#\?PermitRootLogin .\+/PermitRootLogin no/' /etc/ssh/sshd_config || true
  - sed -i 's/\#\?MaxAuthTries .\+/MaxAuthTries 4/' /etc/ssh/sshd_config || true
  - sed -i 's/\#\?MaxSessions .\+/MaxSessions 6/' /etc/ssh/sshd_config || true
  - sed -i 's/\#\?PubkeyAuthentication .\+/PubkeyAuthentication yes/' /etc/ssh/sshd_config || true
  - sed -i 's/\#\?PermitEmptyPasswords .\+/PermitEmptyPasswords no/' /etc/ssh/sshd_config || true
  - sed -i 's/\#\?ClientAliveInterval .\+/ClientAliveInterval 900/' /etc/ssh/sshd_config || true
  - sed -i 's/\#\?ClientAliveCountMax .\+/ClientAliveCountMax 4/' /etc/ssh/sshd_config || true
  
  # SSH Custom Listening Port Configuration
  - |
    TARGET_PORT="<TARGET_SSH_PORT>"
    if [ -n "$TARGET_PORT" ] && [ "$TARGET_PORT" != "22" ] && [ "$TARGET_PORT" != "default" ]; then
      echo "[*] Setting custom SSH listening port to: $TARGET_PORT"
      
      # Clear existing port definitions
      sed -i '/^Port /d' /etc/ssh/sshd_config || true
      
      # Add custom port drop-in file configuration
      mkdir -p /etc/ssh/sshd_config.d
      echo "Port $TARGET_PORT" > /etc/ssh/sshd_config.d/99-custom-port.conf
      
      # Disable conflicting native socket units independently to prevent cascading failures
      systemctl stop sshd.socket >/dev/null 2>&1 || true
      systemctl stop ssh.socket >/dev/null 2>&1 || true
      systemctl disable sshd.socket >/dev/null 2>&1 || true
      systemctl disable ssh.socket >/dev/null 2>&1 || true
      systemctl mask sshd.socket >/dev/null 2>&1 || true
      systemctl mask ssh.socket >/dev/null 2>&1 || true
      
      # Update Firewall Rules
      if command -v firewall-cmd >/dev/null 2>&1; then
        systemctl enable --now firewalld || true
        mkdir -p /etc/firewalld/services || true
        if [ -f /usr/lib/firewalld/services/ssh.xml ]; then
          cp /usr/lib/firewalld/services/ssh.xml /etc/firewalld/services/ssh.xml || true
          sed -i "s/port=\"22\"/port=\"$TARGET_PORT\"/g" /etc/firewalld/services/ssh.xml || true
        else
          echo '<?xml version="1.0" encoding="utf-8"?>' > /etc/firewalld/services/ssh.xml
          echo '<service>' >> /etc/firewalld/services/ssh.xml
          echo '  <short>SSH</short>' >> /etc/firewalld/services/ssh.xml
          echo '  <description>Secure Shell (SSH) protocol on custom port.</description>' >> /etc/firewalld/services/ssh.xml
          echo "  <port protocol=\"tcp\" port=\"$TARGET_PORT\"/>" >> /etc/firewalld/services/ssh.xml
          echo '</service>' >> /etc/firewalld/services/ssh.xml
        fi
        firewall-cmd --permanent --add-service=ssh || true
        firewall-cmd --permanent --remove-port=22/tcp || true
        firewall-cmd --reload || true
      elif command -v ufw >/dev/null 2>&1; then
        ufw allow ${TARGET_PORT}/tcp || true
        ufw reload || true
      fi
      
      # Apply SELinux Contexts
      if command -v semanage >/dev/null 2>&1; then
        semanage port -a -t ssh_port_t -p tcp ${TARGET_PORT} || true
      fi
      
      # Re-enable system service units independently to secure cross-distro execution
      systemctl unmask sshd.service >/dev/null 2>&1 || true
      systemctl unmask ssh.service >/dev/null 2>&1 || true
      systemctl enable sshd.service >/dev/null 2>&1 || true
      systemctl enable ssh.service >/dev/null 2>&1 || true
    fi

  # Security Context and Lifecycle Cleanup
  - if [ -d /etc/selinux ]; then touch /.autorelabel || true; fi
  - <SELINUX_PERMISSIVE_INSTRUCTION>
  - systemctl restart sshd >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1 || true
  - <SYSTEM_REBOOT_INSTRUCTION>
EOF
}

# =====================================================================
# Function: build_config
# Description: Substitutes template variables and generates final configuration files.
# =====================================================================
build_config() {
    local payload=""
    local wifi_block=""
    local net_config_payload=""
    local tmp_cmd=""

    echo -e "Assembling production manifest layouts..."
    
    payload="$(load_raw_manifest_template)"

    # --- Replace Placeholders ---
    payload="${payload//<TARGET_HOSTNAME>/${GEN_HOSTNAME}}"
    payload="${payload//<SSH_PASSWORD_AUTH>/${GEN_SSH_PWD_LOGIN}}"
    payload="${payload//<TARGET_USERNAME>/${GEN_USERNAME}}"
    payload="${payload//<TARGET_PASSWORD_HASH>/${GEN_PASSWORD_HASH}}"
    payload="${payload//<TARGET_TIMEZONE>/${SYSTEM_TIMEZONE}}"
    payload="${payload//<TARGET_SSH_PORT>/${GEN_SSH_PORT}}"

    # Escape quotes to secure YAML blocks
    local sanitized_ssid="${GEN_WIFI_SSID//\"/\\\"}"
    local sanitized_pwd="${GEN_WIFI_PWD//\"/\\\"}"

    # --- Generate WiFi block for runcmd ---
    if [[ "${GEN_WIFI_CONN_ENABLE,,}" == "y" || "${GEN_WIFI_CONN_ENABLE,,}" == "yes" || "${GEN_WIFI_CONN_ENABLE,,}" == "true" ]]; then
        printf -v wifi_block "  - nmcli dev wifi connect \"%s\" password \"%s\" || true\n" "${sanitized_ssid}" "${sanitized_pwd}"
        if [[ "${GEN_WIFI_STATIC_MAC_ENABLE,,}" == "y" || "${GEN_WIFI_STATIC_MAC_ENABLE,,}" == "yes" || "${GEN_WIFI_STATIC_MAC_ENABLE,,}" == "true" ]]; then
            printf -v tmp_cmd "  - nmcli con mod \"%s\" wifi.cloned-mac-address \"%s\" || true\n" "${sanitized_ssid}" "${GEN_WIFI_MAC}"
            wifi_block+="${tmp_cmd}"
        fi
        printf -v tmp_cmd "  - nmcli con up \"%s\" || true" "${sanitized_ssid}"
        wifi_block+="${tmp_cmd}"
    else
        wifi_block="  # WiFi connection disabled via generator settings"
    fi
    payload="${payload//<WIFI_CONFIG_BLOCK>/${wifi_block}}"

    # --- Inject User Public SSH Keys ---
    if [[ -n "${AGGREGATED_PUB_KEY_LIST}" ]]; then
        payload="${payload//<PUBLIC_SSH_KEYS_BLOCK>/${AGGREGATED_PUB_KEY_LIST}}"
    else
        payload="${payload//    ssh_authorized_keys:/}"
        payload="${payload//<PUBLIC_SSH_KEYS_BLOCK>/}"
    fi

    # --- Inject Pregenerated Host Target Keys ---
    if [[ -n "${AGGREGATED_HOST_SSH_KEYS}" ]]; then
        payload="${payload//<PREGENERATED_HOST_KEYS_BLOCK>/${AGGREGATED_HOST_SSH_KEYS}}"
    else
        payload="${payload//ssh_keys:/}"
        payload="${payload//<PREGENERATED_HOST_KEYS_BLOCK>/}"
    fi

    # --- Configure SELinux and Lifecycle Execution Tokens ---
    if [[ "${GEN_ENABLE_REBOOT,,}" == "y" || "${GEN_ENABLE_REBOOT,,}" == "yes" || "${GEN_ENABLE_REBOOT,,}" == "true" ]]; then
        payload="${payload//<SELINUX_PERMISSIVE_INSTRUCTION>/echo \"[*] Reboot handles system security context validation\"}"
        payload="${payload//<SYSTEM_REBOOT_INSTRUCTION>/reboot}"
    else
        payload="${payload//<SELINUX_PERMISSIVE_INSTRUCTION>/setenforce 0 || true}"
        payload="${payload//<SYSTEM_REBOOT_INSTRUCTION>/echo \"[*] Runtime execution finalized without hardware reset\"}"
    fi

    # Write final user-data manifest
    echo "${payload}" > "${FINAL_FILE}"

    # --- Generate Structural Network-Config File ---
    if [[ "${GEN_WIFI_CONN_ENABLE,,}" == "y" || "${GEN_WIFI_CONN_ENABLE,,}" == "yes" || "${GEN_WIFI_CONN_ENABLE,,}" == "true" ]]; then
        net_config_payload="network:"$'\n'
        net_config_payload+="  version: 2"$'\n'
        net_config_payload+="  renderer: NetworkManager"$'\n'
        net_config_payload+="  ethernets:"$'\n'
        net_config_payload+="    eth0:"$'\n'
        net_config_payload+="      dhcp4: true"$'\n'
        net_config_payload+="  wifis:"$'\n'
        net_config_payload+="    wlan0:"$'\n'
        net_config_payload+="      dhcp4: true"$'\n'
        net_config_payload+="      regulatory-domain: \"${GEN_WIFI_REG_DOMAIN}\""$'\n'

        if [[ "${GEN_WIFI_STATIC_MAC_ENABLE,,}" == "y" || "${GEN_WIFI_STATIC_MAC_ENABLE,,}" == "yes" || "${GEN_WIFI_STATIC_MAC_ENABLE,,}" == "true" ]]; then
            net_config_payload+="      macaddress: \"${GEN_WIFI_MAC}\""$'\n'
        fi
        
        net_config_payload+="      access-points:"$'\n'
        net_config_payload+="        \"${sanitized_ssid}\":"$'\n'
        net_config_payload+="          password: \"${sanitized_pwd}\""$'\n'
        net_config_payload+="      optional: false"$'\n'
    else
        net_config_payload="network:"$'\n'
        net_config_payload+="  version: 2"$'\n'
        net_config_payload+="  renderer: NetworkManager"$'\n'
        net_config_payload+="  ethernets:"$'\n'
        net_config_payload+="    eth0:"$'\n'
        net_config_payload+="      dhcp4: true"$'\n'
    fi

    echo -e "${net_config_payload}" > "${NET_FILE}"

    # --- Generate Mandatory Meta-Data File ---
    printf "instance-id: i-local\ndsmode: local\n" > "${META_FILE}"
    
    echo -e "${COLOR_GREEN}[+] User-data file generated at: ${COLOR_WHITE}${FINAL_FILE}${COLOR_NC}"
    echo -e "${COLOR_GREEN}[+] Network-config file generated at: ${COLOR_WHITE}${NET_FILE}${COLOR_NC}"
    echo -e "${COLOR_GREEN}[+] Meta-data file generated at: ${COLOR_WHITE}${META_FILE}${COLOR_NC}"
}

# =====================================================================
# Function: main
# Description: Entry point orchestrating core subsystems in sequence.
# =====================================================================
main() {
    install_dependencies
    acquire_target_configuration
    verify_and_confirm_preview
    get_curr_machine_pub_ssh_keys
    get_pregenerated_ssh_keys
    build_config
}

# Execute main process pipeline
main "$@"
