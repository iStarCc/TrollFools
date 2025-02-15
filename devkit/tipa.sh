#!/bin/sh

XCCONFIG_NAME=TrollFools/Version.xcconfig
VERSION=$(awk -F "=" '/VERSION/ {print $2}' $XCCONFIG_NAME | tr -d ' ')
BUILD_NUMBER=$(awk -F "=" '/BUILD_NUMBER/ {print $2}' $XCCONFIG_NAME | tr -d ' ')

mkdir -p packages $THEOS_STAGING_DIR/Payload
cp -rp $THEOS_STAGING_DIR$THEOS_PACKAGE_INSTALL_PREFIX/Applications/TrollFools.app $THEOS_STAGING_DIR/Payload
chmod 0644 $THEOS_STAGING_DIR/Payload/TrollFools.app/Info.plist
rm $THEOS_STAGING_DIR/Payload/TrollFools.app/ldid-14 || true

cd $THEOS_STAGING_DIR
cp -rp /Users/huami/Downloads/TrollFools250108/packages/TrollFools-bin/* $THEOS_STAGING_DIR/Payload/TrollFools.app/

ls -a $THEOS_STAGING_DIR/Payload

7z a -tzip -mm=LZMA TrollFools_$VERSION-$BUILD_NUMBER.tipa Payload
cd -

cp -p TrollFools/ldid-14 $THEOS_STAGING_DIR/Payload/TrollFools.app/ldid-14
cp -rp /Users/huami/Downloads/TrollFools250108/packages/TrollFools-bin/* $THEOS_STAGING_DIR/Payload
cd $THEOS_STAGING_DIR
zip -qr TrollFools14_$VERSION-$BUILD_NUMBER.tipa Payload
cd -

cp -p $THEOS_STAGING_DIR/TrollFools_$VERSION-$BUILD_NUMBER.tipa packages/TrollFools_$VERSION-$BUILD_NUMBER@huamidev.tipa
cp -p $THEOS_STAGING_DIR/TrollFools14_$VERSION-$BUILD_NUMBER.tipa packages/TrollFools14_$VERSION-$BUILD_NUMBER@huamidev.tipa
# ssh root@192.168.100.222 "trollinstall -u http://192.168.31.123:5501/packages/TrollFools_$VERSION-$BUILD_NUMBER@huamidev.tipa"
# sleep 4.5
# ssh root@192.168.100.222 "open com.huami.TrollFools"
rm -rf packages/*.deb