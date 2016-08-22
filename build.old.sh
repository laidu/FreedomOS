#!/bin/bash
# FreedomOS build script
# Author : Nevax
# Contributor : TimVNL

set -e

VERSION=0
DEVICE=0
MENU=0
DEVICEMENU=0
SDAT2IMG_LINK="https://raw.githubusercontent.com/xpirt/sdat2img/master/sdat2img.py"

redt=$(tput setaf 1)
redb=$(tput setab 1)
greent=$(tput setaf 2)
greenb=$(tput setab 2)
yellowt=$(tput setaf 3)
yellowb=$(tput setab 3)
bluet=$(tput setaf 4)
blueb=$(tput setab 4)
magentat=$(tput setaf 5)
magentab=$(tput setab 5)
cyant=$(tput setaf 6)
cyanb=$(tput setab 6)
whiteb=$(tput setab 7)
bold=$(tput bold)
italic=$(tput sitm)
stand=$(tput smso)
underline=$(tput smul)
normal=$(tput sgr0)
clears=$(tput clear)

banner() {
	echo "$clears"
  echo "----------------------------------------"
  echo "$bold$redt    FreedomOS build script by Nevax $normal"
  echo "----------------------------------------"
  echo
}

function error_exit() {
	echo "$bold$redt$1" 1>&2
	echo "Error: $2$normal"
	exit $2
}

function confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

if [ "$EUID" -ne 0 ]; then
	error_exit "Please, run this script as root! Aborting." "7"
fi

# Show device list
banner
echo "Available devices:"
echo
find . -name "*.fos" -exec basename \{} .fos \;
echo
read -p "Enter your device codename: " DEVICE
echo

if [ -f device/$DEVICE/$DEVICE.fos ];
then
  source device/$DEVICE/$DEVICE.fos
else
  echo "Can not find $DEVICE.fos file!"
  exit
fi

# Choose build method option
banner
echo "Choose the build method you want:"
echo "1) user-release"
echo "2) debug"
echo
read -p "enter build method [debug]: " BUILD

if [ "$BUILD" = 1 ];
then
  BUILD_TYPE=user-release
  echo "user-release selected"
elif [ "$BUILD" = 2 ];
then
  BUILD_TYPE=debug
  echo "debug selected"
else
  BUILD=2
  BUILD_TYPE=debug
  echo "debug selected"
fi

# Enter version number option
banner
read -p "Enter the version number [test] : " VERSION

if [ -z "$VERSION" ];
then
  VERSION="test"
fi

# Show Build review
banner
echo "Build review:"
echo
echo "Device target: $DEVICE"
echo "Build type: $BUILD_TYPE"
echo "Build version: $VERSION"
echo "Arch: $ARCH"
echo "Codename: $CODENAME"
echo "Assert: $ASSERT"
echo "ROM name: $ROM_NAME"
echo "ROM Link: $ROM_LINK"
echo "ROM MD5: $ROM_MD5"
echo "SuperSU zip: $SU"
echo "Xposed apk: $XPOSED_APK"
echo "Audio mod: $DIVINE"
echo
if [[ "no" == $(confirm "All options correct?") ]]
then
  error_exit "Stopping build now! To start a new build restart the script." "0"
fi
# Building Process
banner
echo "$DEVICE build starting now."
echo

echo "Clear tmp/ foler..."
if mount | grep "FreedomOS/tmp/mount" > /dev/null;
then
	echo "umount tmp/mount/"
	umount tmp/mount/
fi
rm -rvf tmp/*
touch tmp/EMPTY_DIRECTORY

echo
echo "Clear output/ foler..."
#TODO: Delete only the file with the same name
rm -rvf output/*.zip
rm -rvf output/*.md5

echo
echo "Checking dependencies..."
echo
echo "Checking MD5 of $ROM_NAME"
echo
if [[ $ROM_MD5 == $(md5sum download/$ROM_NAME.zip | cut -d ' ' -f 1) ]];
then
  echo "MD5 $ROM_NAME.zip checksums OK."
else
  echo "File $ROM_NAME.zip does not exist or the file is corrupt" >&2
	echo
  if curl -Is $ROM_LINK | grep "200 OK" &> /dev/null
  then
    echo "Downloading $ROM_NAME..."
		#TODO Ask user for delete or change name of the old corrupted zip
		rm -vf download/$ROM_NAME.zip
    curl -o download/$ROM_NAME.zip $ROM_LINK
  else
    error_exit "$ROM_NAME mirror OFFLINE! Check your connection" "10"
  fi
fi
echo

if [ -f rom/$DEVICE/$ROM_NAME/system.new.dat ];
then
  echo "rom/$DEVICE/$ROM_NAME dir exist."
else
  echo
  echo "Extracting rom zip"
  mkdir -p rom/$DEVICE/$ROM_NAME
  unzip -o download/$ROM_NAME.zip -d rom/$DEVICE/$ROM_NAME
  echo Done!
fi

echo "Updating sdat2img tools"
if curl -Is $SDAT2IMG_LINK | grep "200 OK" &> /dev/null
then
  curl -o build/tools/sdat2img.py $SDAT2IMG_LINK
else
  echo "$yellowt sdat2img tools mirror is OFFLINE! sdat2img tools not updated $normal"
fi
chmod +x build/tools/*

echo
echo "Copy $ROM_NAME needed files:"
rsync -rv rom/$DEVICE/$ROM_NAME/* tmp/ --exclude='system.transfer.list' --exclude='system.new.dat' --exclude='system.patch.dat' --exclude='META-INF/'
mkdir -p tmp/mount
mkdir -p tmp/system
echo
echo "Extracting system.new.dat:"
build/tools/sdat2img.py rom/$DEVICE/$ROM_NAME/system.transfer.list rom/$DEVICE/$ROM_NAME/system.new.dat tmp/system.img
echo
echo "Mounting system.img:"
mount -t ext4 -o loop tmp/system.img tmp/mount/
echo
echo "Extracting system files:"
cp -rvf tmp/mount/* tmp/system/
echo
echo "Clean tmp/"
if mount | grep "FreedomOS/tmp/mount" > /dev/null;
then
		echo "umount tmp/mount/"
		sleep 2
		umount tmp/mount/
fi
rm -rvf tmp/mount
rm -rvf tmp/system.*

echo
echo "Remove unneeded system files"
for i in ${CLEAN_LIST}
do
	rm -rvf tmp${i}
done

echo
echo "Patching system files:"
cp -rvf assets/system/${ARCH}/* tmp/system

#echo
#echo "Copying data files:"
#cp -rvf data tmp/data

echo
echo "Add aroma"
mkdir -p tmp/META-INF/com/google/android/
cp -vR device/$DEVICE/aroma/* tmp/META-INF/com/google/android/
echo
echo "Add tools"
#cp -vR "tools" "tmp/"
mkdir tmp/tools
for i in ${TOOLS_LIST}
do
	cp -rvf assets/tools/${i} tmp/tools/
done

echo
echo "Add FreedomOS wallpapers by badboy47"
mkdir -p tmp/media/wallpaper
cp -v media/wallpaper/* tmp/media/wallpaper

echo
echo "Set Assert in updater-script"
sed -i.bak "s:!assert!:$ASSERT:" tmp/META-INF/com/google/android/updater-script
echo
echo "Set version in aroma"
sed -i.bak "s:!version!:$VERSION:" tmp/META-INF/com/google/android/aroma-config
echo
echo "Set version in aroma"
sed -i.bak "s:!device!:$DEVICE:" tmp/META-INF/com/google/android/aroma-config
echo
echo "Set date in aroma"
sed -i.bak "s:!date!:$(date +"%d%m%y"):" tmp/META-INF/com/google/android/aroma-config
echo
echo "Set date in en.lang"
sed -i.bak "s:!date!:$(date +"%d%m%y"):" tmp/META-INF/com/google/android/aroma/langs/en.lang
echo
echo "Set date in fr.lang"
sed -i.bak "s:!date!:$(date +"%d%m%y"):" tmp/META-INF/com/google/android/aroma/langs/fr.lang
rm -rvf tmp/META-INF/com/google/android/aroma-config.bak
rm -rvf tmp/META-INF/com/google/android/aroma/langs/*.lang.bak

## user release build
if [ "$BUILD" = 1 ];
then
  cd tmp/
  echo
  echo "Making zip file"
  zip -r9 "FreedomOS-$CODENAME-nevax-$VERSION.zip" * -x "*EMPTY_DIRECTORY*"
  echo "----"
  cd ..
  echo
  echo "Copy Unsigned in output folder"
  cp -v tmp/FreedomOS-$CODENAME-nevax-$VERSION.zip output/FreedomOS-$CODENAME-nevax-$VERSION.zip
  echo
  echo "testing zip integrity"
  zip -T output/FreedomOS-$CODENAME-nevax-$VERSION.zip
  echo
  echo "Generating md5 hash"
  openssl md5 "output/FreedomOS-$CODENAME-nevax-$VERSION.zip" |cut -f 2 -d " " > "output/FreedomOS-$CODENAME-nevax-$VERSION.zip.md5"
  echo
  echo "SignApk....."
	chmod +x build/tools/signapk.jar
  java -jar "build/tools/signapk.jar" "build/keys/certificate.pem" "build/keys/key.pk8" "tmp/FreedomOS-$CODENAME-nevax-$VERSION.zip" "output/FreedomOS-$CODENAME-nevax-$VERSION-signed.zip"
  echo
  echo "Generating md5 hash"
  openssl md5 "output/FreedomOS-$CODENAME-nevax-$VERSION-signed.zip" |cut -f 2 -d " " > "output/FreedomOS-$CODENAME-nevax-$VERSION-signed.zip.md5"
  #We doesn't test the final, because it doesn't work with the signed zip.
  FINAL_ZIP=FreedomOS-$CODENAME-nevax-$VERSION-signed
fi

## debug build
if [ "$BUILD" = 2 ];
then
  cd tmp/
  echo
  echo "Making zip file"
  zip -r1 "FreedomOS-$CODENAME-$BUILD_TYPE-$VERSION.zip" * -x "*EMPTY_DIRECTORY*"
  echo "----"
  echo
  echo "testing zip integrity"
  zip -T "FreedomOS-$CODENAME-$BUILD_TYPE-$VERSION.zip"
  echo
  cd ..
  echo "Move unsigned zip file in output folder"
  mv -v "tmp/FreedomOS-$CODENAME-$BUILD_TYPE-$VERSION.zip" "output/"
  echo
  echo "Generating md5 hash"
  openssl md5 "output/FreedomOS-$CODENAME-$BUILD_TYPE-$VERSION.zip" |cut -f 2 -d " " > "output/FreedomOS-$CODENAME-$BUILD_TYPE-$VERSION.zip.md5"
  FINAL_ZIP=FreedomOS-$CODENAME-$BUILD_TYPE-$VERSION
fi

echo
echo "Clear tmp/ foler..."
rm -rf tmp/*
touch "tmp/EMPTY_DIRECTORY"
echo
echo "$greent$bold Build finished! You can find the build here: output/FreedomOS-$CODENAME-$BUILD_TYPE-$VERSION.zip $normal"
echo
if [[ "yes" == $(confirm "Want to flash it now?") ]]
then
  ## ADB Push zip on device
  echo
  echo "Pushing $FINAL_ZIP.zip to your $DEVICE..."
  adb shell "rm /sdcard/$FINAL_ZIP.zip"
  adb push -p output/$FINAL_ZIP.zip /sdcard/
  echo "Pushing $FINAL_ZIP.zip.md5 to your $DEVICE..."
  adb shell "rm /sdcard/$FINAL_ZIP.zip.md5"
  adb push -p output/$FINAL_ZIP.zip.md5 /sdcard/
  adb shell "chown -R media_rw:media_rw /sdcard/FreedomOS*"
  ## Flashing zip on device
  echo
  echo "Flashing $FINAL_ZIP.zip into TWRP"
  adb shell "echo 'boot-recovery ' > /cache/recovery/command"
  adb shell "echo '--update_package=/sdcard/$FINAL_ZIP.zip' >> /cache/recovery/command"
  adb shell reboot recovery
  echo
  echo "$greent$bold Flash Successful! Follow the steps on you device $normal"
fi