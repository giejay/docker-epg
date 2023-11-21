#!/bin/bash

. $(dirname $0)/guides.sh

BUILD_DIR=/build
OUT_DIR=$BUILD_DIR/guides
LOCK_FILE=$BUILD_DIR/.lock
ONCE_FILE=$BUILD_DIR/.once

[ -f $LOCK_FILE ] && exit
if [ "x-$1" = "x-oneshot" ]; then
  [ -f $ONCE_FILE ] && exit
  touch $ONCE_FILE
fi

echo "=== `basename $0` ==="

touch $LOCK_FILE

cd $BUILD_DIR
if [ ! -d $BUILD_DIR/epg ]; then
  echo "Cloning EPG source..."
  git clone https://github.com/iptv-org/epg.git epg && cd $BUILD_DIR/epg
else
  echo "Updating EPG source..."
  cd $BUILD_DIR/epg
  git checkout package-lock.json
  git stash save
  git pull
  git stash apply
fi

echo "Updating npm modules..."
npm update

echo "Preparing directory..."
mkdir -p $OUT_DIR
GUIDE_DIR=$(basename $OUT_DIR)
[ ! -h "${GUIDE_DIR}" ] && ln -s ../${GUIDE_DIR} ${GUIDE_DIR}

echo "Loading EPG api..."
npm run api:load

for SITE in $SITES; do
  GUIDE_XML=$GUIDE_DIR/$SITE.xml
  CNT=0
  # build guide use configured language
  for LANG in $LANGS; do
    if [ -f sites/$SITE/${SITE}_$LANG.channels.xml ]; then
      echo "Building guide for $SITE ($LANG)..."
      npm run grab -- --site=$SITE --lang=$LANG --output=$GUIDE_XML 1>~/$SITE.log 2>&1 &
      CNT=$((CNT+1))
    fi
  done
  # no guide for configured language, use default
  if [ $CNT -eq 0 ]; then
    echo "Building guide for $SITE..."
    npm run grab -- --site=$SITE --output=$GUIDE_XML 1>~/$SITE.log 2>&1 &
  fi
done

rm -f $LOCK_FILE
