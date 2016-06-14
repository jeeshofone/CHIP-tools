#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

if ! wait_for_fel; then
  echo "ERROR: please jumper your CHIP in FEL mode then power on"
  exit 1
fi


FLASH_SCRIPT=./chip-fel-flash.sh
WHAT=buildroot
BRANCH=stable

function require_directory {
  if [[ ! -d "${1}" ]]; then
    mkdir -p "${1}"
  fi
}

function s3_md5 {
  local URL=$1
  curl -sLI $URL |grep ETag|sed -e 's/.*"\([a-fA-F0-9]\+\)["-]*.*/\1/;'
}

function cache_download {
  local DEST_DIR=${1}
  local SRC_URL=${2}
  local FILE=${3}

  if [[ -f "${DEST_DIR}/${FILE}" ]]; then
    echo "${DEST_DIR}/${FILE} exists... comparing to ${SRC_URL}/${FILE}"
    local S3_MD5=$(s3_md5 ${SRC_URL}/${FILE})
    local MD5=$(md5sum ${DEST_DIR}/${FILE} | cut -d\  -f1)
    echo "MD5: ${MD5}"
    echo "S3_MD5: ${S3_MD5}"
    if [[ "${S3_MD5}" != "${MD5}" ]]; then
      echo "md5sum differs"
      rm ${DEST_DIR}/${FILE}
      if ! wget -P "${FW_IMAGE_DIR}" "${SRC_URL}/${FILE}"; then
        echo "download of ${SRC_URL}/${FILE} failed!"
        exit $?
      fi 
    else
      echo "file already downloaded"
    fi
  else
    if ! wget -P "${FW_IMAGE_DIR}" "${SRC_URL}/${FILE}"; then
      echo "download of ${SRC_URL}/${FILE} failed!"
      exit $?
    fi 
  fi
}
    

while getopts "ufdpb:w:B:" opt; do
  case $opt in
    u)
      echo "updating cache"
      if [[ -d "$FW_IMAGE_DIR" ]]; then
        rm -rf $FW_IMAGE_DIR
      fi
      ;;
    f)
      echo "fastboot enabled"
      FLASH_SCRIPT_OPTION="-f"
      ;;
    B)
      BUILD="$OPTARG"
      echo "BUILD = ${BUILD}"
      ;;
    b)
      BRANCH="$OPTARG"
      echo "BRANCH = ${BRANCH}"
      ;;
    w)
      WHAT="$OPTARG"
      echo "WHAT = ${WHAT}"
      ;;
    d)
      echo "debian selected"
      WHAT="debian"
      ;;
    p)
      echo "PocketC.H.I.P selected"
      WHAT="pocketchip"
      BUILD=123
      FLASH_SCRIPT=./chip-fel-flash.sh -p
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done


FW_DIR="$(pwd)/.firmware"
FW_IMAGE_DIR="${FW_DIR}/images"
BASE_URL="http://opensource.nextthing.co/chip"
S3_URL="${BASE_URL}/${WHAT}/${BRANCH}/latest"



if [[ ! -z "$BUILD" ]]; then
  case "${WHAT}" in
    "buildroot")
      if [[ "$BUILD" -lt "74" ]] && [[ "${BRANCH}" == "stable" ]]; then
            ./chip-legacy-update.sh $@ || echo "ERROR: could not flash" && exit 1
            exit 0
      fi
      if [[ "$BUILD" -lt "60" ]] && [[ "${BRANCH}" == "next" ]]; then
            ./chip-legacy-update.sh $@ || echo "ERROR: could not flash" && exit 1
            exit 0
      fi
    ;;
    "debian")
      if [[ "$BUILD" -lt "47" ]] && [[ "${BRANCH}" == "stable" ]]; then
        ./chip-legacy-update.sh $@ || echo "ERROR: could not flash" && exit 1
        exit 0
      fi
      if [[ "$BUILD" -lt "148" ]] && [[ "${BRANCH}" == "next" ]]; then
        ./chip-legacy-update.sh $@ || echo "ERROR: could not flash" && exit 1
        exit 0
      fi
      if [[ "$BUILD" -lt "4" ]] && [[ "${BRANCH}" == "stable-gui" ]]; then
        ./chip-legacy-update.sh $@ || echo "ERROR: could not flash" && exit 1
        exit 0
      fi
      if [[ "$BUILD" -lt "148" ]] && [[ "${BRANCH}" == "next-gui" ]]; then
        ./chip-legacy-update.sh $@ || echo "ERROR: could not flash" && exit 1
        exit 0
      fi
    ;;
  esac
else
  ROOTFS_URL="${S3_URL%latest}$BUILD"
fi

exit $?
