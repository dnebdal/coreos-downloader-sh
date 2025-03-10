#!/bin/sh
# Copyright 2025 Daniel Nebdal <daniel@nebdal.no>
# SPDX-License-Identifier: BSD-2-Clause

### CoreOS stream settings:
# FILE should be the filename you get when downloading the URL
URL="https://builds.coreos.fedoraproject.org/streams/stable.json"
FILE="stable.json"
CWD=$(pwd)

### Show minimal instructions
print_help() {
  echo "Usage: "
  echo "get_coreos.sh list-arch                        : List available architectures"
  echo "get_coreos.sh list-formats <arch>              : List available formats" 
  echo "get_coreos.sh get <arch> <platform> <version>  : Download and verify"
  echo ""
  echo "Requires a download tool (wget, curl, fetch), jq, and sha256sum to run."
}

# When run with no arguments or --help, print help and exit
if [ $# -eq 0 ] || [ "$1" == "--help" ]; then
  print_help
  exit 0
fi

### Find our tools:
## Downloader:
# OPTS and QOPTS are used for verbose and quiet downloads, respectively.
OPTS=""
QOPTS="-q"
FETCH=$(which fetch 2> /dev/null)
if [ -z "$FETCH" ]; then FETCH=$(which wget 2> /dev/null); OPTS=""  ; QOPTS="-q"; fi
if [ -z "$FETCH" ]; then FETCH=$(which curl 2> /dev/null); OPTS="-O"; QOPTS="-s -O "; fi
if [ -z "$FETCH" ]; then echo "Could not find fetch, wget or curl!"; exit 1; fi

## jq:
JQ=$(which jq)
if [ -z "$JQ" ]; then 
  echo "Could not find jq in PATH!"
  exit 1
fi

## sha256sum:
CSUMTOOL=$(which sha256sum)
if [ -z "$CSUMTOOL" ]; then 
  echo "Could not find sha256sum in PATH!"
  exit 1
fi
  
### Utility functions:
download() {
  $FETCH $OPTS "$1"
}

download_quiet() {
  $FETCH $QOPTS "$1" >/dev/null
}

### Utility functions

# List available architectures
listarch() {
  cat "$FILE" | jq '.architectures | keys[]' | tr -d '"'
}

# List the artifacts and formats available for the given architecture
# Artifacts are roughly "platforms": "AWS" or [raw] "metal" etc
# Formats are assorted VM disk images and iso and "pxe" for network boots
listformats() {
  PLATFORMS=$(cat "$FILE" | jq ".architectures.$1.artifacts | keys[]" | tr -d '"' | tr '\n' ' ')
  for p in $PLATFORMS; do
    FORMATS=$(cat "$FILE" | jq ".architectures.$1.artifacts.$p.formats | keys[]" | tr -d '"'| tr '\n' ' ')
    for i in $FORMATS; do printf "% 10s\t%s\n" "$p" "$i"; done
  done
}

# Download the file or files for the given arch/artifact/format triplet.
# Most formats have just one item, usually "disk",
# but e.g. PXE has multiple. Download and check each one.
# The stream json contains both the expected sha256 sum
# and the URL to a checksum file; this uses the former.
get_files() {
  JQPATH=".architectures.$1.artifacts.$2.formats.$3"
  ITEMS=$(cat "$FILE" | jq "$JQPATH | keys[]" | tr -d '"' | tr '\n' ' ')

  for item in $ITEMS; do
    echo ">> $item"
    ITEMURL=$(cat "$FILE" | jq "$JQPATH.$item.location" | tr -d '"')
    ITEMFILE=$(basename $ITEMURL)
    CKSUM=$(cat "$FILE" | jq "$JQPATH.$item.sha256" | tr -d '"')

    # Download to the directory we launched from
    cd "$CWD"
    download "$ITEMURL"
    CKSUM_LOCAL=$($CSUMTOOL "$ITEMFILE" | cut -d' ' -f1)
    cd "$TMPDIR"

    # This is untested until I find a way to inject a wrong file or checksum 
    if [ "$CKSUM" == "$CKSUM_LOCAL" ]; then
      echo "Checksums match"
    else
      echo "Checksums differ:"
      echo "Got $CKSUM_LOCAL"
      echo "Expected $CKSUM"
      exit 1
    fi
  done
}


### Do the work.

# We store a local copy of the json file, 
# in a temp directory to avoid overwriting anything.
# Try to make a good temporary filename: Our PID should be decently unique
TMPDIR="/tmp/coreos-download.$$"
mkdir "$TMPDIR"
cd "$TMPDIR"

if [ ! -d "$TMPDIR" ]; then
  echo "Could not create temporary directory $TMPDIR"
  exit 1
fi

# Removes the temporary file and directory before exiting
# with the given exit code
cleanup() {
  cd $CWD
  rm "$TMPDIR/$FILE"
  rmdir "$TMPDIR"
  exit $1
}

# This is spiritually a switch/case/default statement over $1:
if [ "$1" == "list-arch" ]; then 
  download_quiet "$URL"
  listarch
  cleanup 0
fi

if [ "$1" == "list-formats" ]; then
  if [ $# -eq 2 ]; then 
    download_quiet "$URL"
    listformats $2
  else
    echo "Usage: get_coreos.sh list-formats <arch>"
    echo "(Got wrong number of arguments)"
    cleanup 1
  fi
  cleanup 0 
fi

if [ "$1" == "get" ]; then 
  if [ $# -eq 4 ]; then
    download_quiet "$URL"
    get_files $2 $3 $4
  else
    echo "Usage: get_coreos.sh get <arch> <platform> <version>"
    echo "(Got wrong number of arguments)"
    cleanup 1
  fi
  cleanup 0
fi

echo "Unexpected verb $1"
print_help
cleanup 1

