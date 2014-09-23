#!/bin/bash -x

export PKG_VER=`grep 'version' agent/gitagent.ddl | awk -F\" '{print $2}'`

mkdir -p build/usr/share/mcollective/plugins/mcollective
cp -rp agent build/usr/share/mcollective/plugins/mcollective/
cp -rp application build/usr/share/mcollective/plugins/mcollective/

mkdir -p build/usr/sbin
cp -rp client/* build/usr/sbin

BUILDN=${BUILD_NUMBER:=1}

/usr/bin/fakeroot /usr/local/bin/fpm -s dir -t deb -n "mco-gitagent" -f \
  -v ${PKG_VER}.${BUILD_NUMBER} --description "Future MCollective git deploy tool" \
  -a all -m "<list.itoperations@futurenet.com>" -d "mcollective (>= 2.2.0)" \
  -C ./build .
