#!/sbin/sh
# Copyright 2017 Antoine GRAVELOT
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# FreedomOS log saver

cp /tmp/recovery.log /tmp/fos_logs/
mv /sdcard/BusyBox-YDS-installer.log /tmp/fos_logs/
mv /sdcard/open_gapps_log.txt /tmp/fos_logs/
mv /tmp/logs /tmp/fos_logs/opengapps
dmesg > /tmp/fos_logs/dmesg.log
cp -r /cache /tmp/fos_logs/
cp /default.prop /tmp/fos_logs
cp /fstab.qcom /tmp/fos_logs
cp /data/stock_boot_*.img.gz /tmp/fos_logs/
cp /data/su.img /tmp/fos_logs/
tar -czvf /sdcard/FreedomOS_log_installer.tar.gz /tmp/fos_logs/*
