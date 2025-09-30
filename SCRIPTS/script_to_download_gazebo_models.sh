#!/usr/bin/env bash
set -eu

# (C) 2019 Daisuke Sato
# https://tiryoh.mit-license.org/2019

function download_model(){
	if [[ -d $HOME'/.gazebo/models/'$1 ]]; then
		echo model $1 is ready.
	else
		wget -l1 -np -nc -r "http://models.gazebosim.org/"$1 --accept=gz
	fi
}

mkdir -p ~/.gazebo/models && cd ~/.gazebo/models
cd /tmp 
TMPDIR=$(mktemp -d tmp.XXXXXXXXXX) 
cd $TMPDIR 
download_model sun
download_model ground_plane
download_model table
download_model wood_cube_5cm
if [[ -d "models.gazebosim.org" ]]; then
	cd "models.gazebosim.org"
	for i in *; do tar -zvxf "$i/model.tar.gz"; done
	cp -vfR * ~/.gazebo/models/
fi
rm -rf $TMPDIR
