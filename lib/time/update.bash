#!/bin/bash
# Copyright 2012 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# This script rebuilds the time zone files using files
# downloaded from the ICANN/IANA distribution.
#
# To prepare an update for a new Go release,
# consult https://www.iana.org/time-zones for the latest versions,
# update CODE and DATA below, and then run
#
#	./update.bash -commit
#
# That will prepare the files and create the commit.
#
# To review such a commit (as the reviewer), use:
#
#	git codereview change NNNNNN   # CL number
#	cd lib/time
#	./update.bash
#
# If it prints "No updates needed.", then the generated files
# in the CL match the update.bash in the CL.

# Versions to use.
CODE=2025b
DATA=2025b

set -e

cd $(dirname $0)
rm -rf work
mkdir work
go build -o work/mkzip mkzip.go # build now for correct paths in build errors
cd work
mkdir zoneinfo
curl -sS -L -O https://www.iana.org/time-zones/repository/releases/tzcode$CODE.tar.gz
curl -sS -L -O https://www.iana.org/time-zones/repository/releases/tzdata$DATA.tar.gz
tar xzf tzcode$CODE.tar.gz
tar xzf tzdata$DATA.tar.gz

# The PACKRATLIST and PACKRATDATA options are copied from Ubuntu:
# https://git.launchpad.net/ubuntu/+source/tzdata/tree/debian/rules?h=debian/sid
#
# You can see the description of these make variables in the tzdata Makefile:
# https://github.com/eggert/tz/blob/main/Makefile
if ! make CFLAGS=-DSTD_INSPIRED AWK=awk TZDIR=zoneinfo PACKRATDATA=backzone PACKRATLIST=zone.tab posix_only >make.out 2>&1; then
	cat make.out
	exit 2
fi

cd zoneinfo
../mkzip ../../zoneinfo.zip
cd ../..

files="update.bash zoneinfo.zip"
modified=true
if git diff --quiet $files; then
	modified=false
fi

if [ "$1" = "-work" ]; then
	echo Left workspace behind in work/.
	shift
else
	rm -rf work
fi

if ! $modified; then
	echo No updates needed.
	exit 0
fi

echo Updated for $CODE/$DATA: $files

commitmsg="lib/time: update to $CODE/$DATA

Commit generated by update.bash.

For #22487.
"

if [ "$1" = "-commit" ]; then
	echo "Creating commit. Run 'git reset HEAD^' to undo commit."
	echo
	git commit -m "$commitmsg" $files
	echo
	git log -n1 --stat
	echo
fi
