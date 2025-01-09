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
# 进行代码签名
# FILES=($THEOS_STAGING_DIR/Payload/TrollFools.app/*)  # 获取 Payload 目录下的所有文件
# for FILE in "${FILES[@]}"; do
#     echo "Signing $FILE"
#     codesign -s "xxx" "$FILE"  # 替换 xxx 为您的代码签名身份
# done
ls -a $THEOS_STAGING_DIR/Payload

7z a -tzip -mm=LZMA TrollFools_$VERSION-$BUILD_NUMBER.tipa Payload
cd -

cp -p TrollFools/ldid-14 $THEOS_STAGING_DIR/Payload/TrollFools.app/ldid-14
cp -rp /Users/huami/Downloads/TrollFools250108/packages/TrollFools-bin/* $THEOS_STAGING_DIR/Payload
cd $THEOS_STAGING_DIR
zip -qr TrollFools14_$VERSION-$BUILD_NUMBER.tipa Payload
cd -

cp -p $THEOS_STAGING_DIR/TrollFools_$VERSION-$BUILD_NUMBER.tipa $THEOS_STAGING_DIR/TrollFools14_$VERSION-$BUILD_NUMBER.tipa packages