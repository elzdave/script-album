#!/bin/bash
# Android ADB Wireless Debugging helper for Linux
# (c) 2018-2023. David Eleazar

# List of ANSI color escape
#Black        0;30     Dark Gray     1;30
#Red          0;31     Light Red     1;31
#Green        0;32     Light Green   1;32
#Brown/Orange 0;33     Yellow        1;33
#Blue         0;34     Light Blue    1;34
#Purple       0;35     Light Purple  1;35
#Cyan         0;36     Light Cyan    1;36
#Light Gray   0;37     White         1;37

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

adb kill-server
clear
echo -e "${GREEN}Connect your phone using ${LGREEN}USB${NC}!"
echo -e "${GREEN}Now waiting . . ."
adb wait-for-device
AND_DEVICE=$(adb devices | grep "device" | tail -n1 | awk '{print $1}')
AND_DEVICE_IP=$(adb shell ifconfig wlan0 | grep "inet addr" | awk -F":" '{print $2}' | awk '{print $1}')
if [[ "$AND_DEVICE"!="" ]]; then
  PORT=$((($RANDOM*19999/32767)+1000))
  echo -e "${NC}${YELLOW}Device found!${NC}"
  echo -e "${YELLOW}Device : ${LPURPLE}$AND_DEVICE${NC}"
  echo -e "${YELLOW}Device IP : ${LPURPLE}$AND_DEVICE_IP${NC}"
  echo -e "${YELLOW}Assigned port : ${LPURPLE}$PORT${NC}"
  echo -e "${LCYAN}"
  adb tcpip $PORT
  adb connect $AND_DEVICE_IP:$PORT
  echo -e "${LGREEN}Now eject the USB cable from device${NC}"
  echo
  echo -e "You can now start debug your Android device wirelessly."
  echo -e "Please kill the ADB server after your work has been done."
  echo
  echo -e "${RED}Press any key to kill server . . .${NC}"
  read
  adb kill-server
  exit
else
  echo -e "${RED}Device not found!${NC}"
  echo -e "${WHITE}Press any key to exit . . .${NC}"
  read
  exit
fi
