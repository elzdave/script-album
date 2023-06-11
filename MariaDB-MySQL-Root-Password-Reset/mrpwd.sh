#!/bin/bash

# GLobal variables
MY_CNF_DIR=/etc/my.cnf.d
MARIADB_CNF_FILE=${MY_CNF_DIR}/mariadb-server.cnf
MAIN_CONFIG=/etc/my.cnf

# Unicode colors
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

function load_unsecure_config () {
  if [ -d "$MY_CNF_DIR" ] 
  then
    echo "Directory $MY_CNF_DIR exists."
    if [ -f "$MARIADB_CNF_FILE" ]
    then
      echo "Backuping $MARIADB_CNF_FILE as $MARIADB_CNF_FILE.bak . . ."
      sudo cp -p $MARIADB_CNF_FILE $MARIADB_CNF_FILE.bak
      sudo sed -i '/\[mysqld\]/a skip-grant-tables\nskip-networking' $MARIADB_CNF_FILE
    fi 
  else
    echo "Directory $MY_CNF_DIR does not exists. Will edit main $MAIN_CONFIG config."
    echo "Backuping $MAIN_CONFIG as $MAIN_CONFIG.bak . . ."
    sudo cp -p $MAIN_CONFIG $MAIN_CONFIG.bak
    sudo sed -i '/\[mysqld\]/a skip-grant-tables\nskip-networking' $MAIN_CONFIG
  fi
}

function check_restore_secure_config () {
  if [ -d "$MY_CNF_DIR" ] 
  then
    echo "Directory $MY_CNF_DIR exists."
    if [ -f "$MARIADB_CNF_FILE.bak" ]
    then
      echo "Restoring original $MARIADB_CNF_FILE . . ."
      sudo cp -p $MARIADB_CNF_FILE.bak $MARIADB_CNF_FILE
      sudo rm $MARIADB_CNF_FILE.bak
    else
      echo "No backup found."
    fi
  else
    echo "Directory $MY_CNF_DIR does not exists."
    if [ -f "$MAIN_CONFIG.bak" ]
    then
      echo "Restoring original $MAIN_CONFIG . . ."
      sudo cp -p $MAIN_CONFIG.bak $MAIN_CONFIG
      sudo rm $MAIN_CONFIG.bak
    else
      echo "No backup found."
    fi
  fi
}

function begin_unsecure_service() {
  sudo systemctl stop $1
  check_restore_secure_config
  load_unsecure_config
  sudo systemctl start $1
}

function end_unsecure_service() {
  sudo systemctl stop $1
  check_restore_secure_config
  sudo systemctl start $1
}

function get_pwd_reset_query() {
  local MODE=$1
  local PASSWORD=$2

  if [ "$MODE" == "alter_unix" ]
  then
    # This mode works on MariaDB 10.4+, which by default using dual authentication plugins:
    # 'mysql_native_password' and 'unix_socket'
    echo 'ALTER USER `root`@`localhost` IDENTIFIED VIA mysql_native_password USING PASSWORD("'$PASSWORD'") OR unix_socket;'
  elif [ "$MODE" == "alter_pwd_only" ]
  then
    # This mode works on MySQL 5.7+ and MariaDB 10.2+, because ALTER USER is still a new feature on those DB versions
    echo 'ALTER USER `root`@`localhost` IDENTIFIED VIA mysql_native_password USING PASSWORD("'$PASSWORD'");'
  else
    # This mode works on all (?) version of MariaDB and MySQL
    echo 'SET PASSWORD FOR `root`@`localhost` = PASSWORD("'$PASSWORD'");'
  fi
}

function reset_password() {
  local SERVICE_NAME=$1
  local DB_NAME=$2
  local PASSWORD=$3

  begin_unsecure_service $SERVICE_NAME

  ALTER_QUERY=$(get_pwd_reset_query 'set_pwd' $PASSWORD)
  FLUSH_QUERY='FLUSH PRIVILEGES;'
  SQL="${FLUSH_QUERY} ${ALTER_QUERY} ${FLUSH_QUERY}"

  echo -e "Resetting ${CYAN}${DB_NAME}${NC} root password . . ."
  mysql -e "$SQL"
  echo -e "Done reset password! Your new root password is : ${GREEN}${PASSWORD}${NC}"

  end_unsecure_service $SERVICE_NAME
}

# Main function execution
if [ "$1" == "" ]; then
  echo "Usage: mrpwd.sh [new_root_pwd]"
  echo "_____"
  echo "ERROR: You must supply a strong, unique password as an argument."
else
  SERVICE_NAME=$(systemctl list-units --type=service --all | grep -E 'MySQL|MariaDB' | awk -F' ' '{print $1}' | awk -F'.' '{print $1}')
  IS_MARIADB=$(mysql --version | grep MariaDB)
  VERSION_NUMBER=$(mysql --version | awk -F'-' '{print $1}' | awk '{print $5}')

  if [ "$IS_MARIADB" != "" ]; then
    DB=MariaDB
  else
    DB=MySQL
  fi

  echo -e "Your ${CYAN}${DB}${NC} version is ${LPURPLE}${VERSION_NUMBER}${NC}"
  reset_password $SERVICE_NAME $DB $1
fi
