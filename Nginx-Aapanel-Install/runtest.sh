#!/bin/bash

ROOT_PATH=$(cat /var/bt_setupPath.conf)
SETUP_PATH=$ROOT_PATH/server/nginx
VERSION_LIST="1.22 1.23 1.24 1.25 1.26 openresty tengine"
UPDATE_INIT_VERSION="1.22"
UPDATE_LAST_VERSION="tengine"
UPDATE_LIST="1.23 1.24 1.25 1.26 openresty tengine"
NGINX_INSTALLER_NAME=nginx.v2.sh

rm -f runtest.log

# Install - Uninstall test
echo "#######################################" | tee -a runtest.log
echo "Running Install-Uninstall Test" | tee -a runtest.log
for i in $VERSION_LIST
do
    echo "----------------------------" | tee -a runtest.log
    echo "Preparing installation of Nginx ${i}" | tee -a runtest.log
    echo "Running : sh $NGINX_INSTALLER_NAME install ${i} 2>&1 | tee nginx.install-uninstall.${i}.log" | tee -a runtest.log
    { time sh $NGINX_INSTALLER_NAME install $i 2>&1 | tee nginx.install-uninstall.$i.log; } 2>> runtest.log
    /etc/init.d/nginx status | tee -a runtest.log
    echo "Nginx $i has been installed." | tee -a runtest.log
    echo "++++++++++++++++++++++++++++" | tee -a runtest.log
    echo "++++++++++++++++++++++++++++" | tee -a nginx.install-uninstall.$i.log
    echo "Uninstalling Nginx ${i}" | tee -a runtest.log
    echo "Running : sh $NGINX_INSTALLER_NAME uninstall ${i} 2>&1 | tee nginx.install-uninstall.${i}.log" | tee -a runtest.log
    { time sh $NGINX_INSTALLER_NAME uninstall $i 2>&1 | tee -a nginx.install-uninstall.$i.log; } 2>> runtest.log
    /etc/init.d/nginx status | tee -a runtest.log
    echo "Nginx $i has been uninstalled." | tee -a runtest.log
    echo "----------------------------" | tee -a runtest.log
done
echo "#######################################" | tee -a runtest.log
echo | tee -a runtest.log

# Update Test
echo "#######################################" | tee -a runtest.log
echo "Running Update Test" | tee -a runtest.log

# Install initial version
echo "----------------------------" | tee -a runtest.log
echo "Preparing installation of Nginx ${UPDATE_INIT_VERSION}" | tee -a runtest.log
echo "Running : sh $NGINX_INSTALLER_NAME install ${UPDATE_INIT_VERSION} 2>&1 | tee nginx.init.${UPDATE_INIT_VERSION}.log" | tee -a runtest.log
{ time sh $NGINX_INSTALLER_NAME install $UPDATE_INIT_VERSION 2>&1 | tee nginx.init.$UPDATE_INIT_VERSION.log; } 2>> runtest.log
/etc/init.d/nginx status | tee -a runtest.log
echo "Nginx $UPDATE_INIT_VERSION has been installed." | tee -a runtest.log

for i in $UPDATE_LIST
do
    echo "----------------------------" | tee -a runtest.log
    echo "Preparing updation to Nginx version ${i}" | tee -a runtest.log
    echo "Running : sh $NGINX_INSTALLER_NAME update ${i} 2>&1 | tee nginx.update.${i}.log" | tee -a runtest.log
    { time sh $NGINX_INSTALLER_NAME update $i 2>&1 | tee nginx.update.$i.log; } 2>> runtest.log
    /etc/init.d/nginx status | tee -a runtest.log
    echo "Nginx $i has been updated." | tee -a runtest.log
    echo "----------------------------" | tee -a runtest.log
done

# Uninstall last version
echo "Uninstalling Nginx ${UPDATE_LAST_VERSION}" | tee -a runtest.log
echo "Running : sh $NGINX_INSTALLER_NAME uninstall ${UPDATE_LAST_VERSION} 2>&1 | tee nginx.uninstall.${UPDATE_LAST_VERSION}.log" | tee -a runtest.log
{ time sh $NGINX_INSTALLER_NAME uninstall $UPDATE_LAST_VERSION 2>&1 | tee -a nginx.uninstall.$UPDATE_LAST_VERSION.log; } 2>> runtest.log
/etc/init.d/nginx status | tee -a runtest.log
echo "Nginx $UPDATE_LAST_VERSION has been uninstalled." | tee -a runtest.log
echo "----------------------------" | tee -a runtest.log

echo "#######################################" | tee -a runtest.log
echo | tee -a runtest.log
