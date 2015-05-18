#!/bin/bash

ARG=$1
OTF_DIR=$2


 -channel_otf 528 /data1/OTFs/CORRECTED/2015_02_10/488_1515_glyc_a1_003_cor.otf \
 -channel_otf 608 /data1/OTFs/568_1516_a1_004c.otf \
 -channel_k0 528 -0.804300 -1.855500 0.238800 \
 -channel_k0 608 -0.775600 -1.826500 0.270100 \
 -channel_ex_linespacing 488 0.207500 \
 -channel_ex_linespacing 568 0.229000 \


#check if first argument is directory

if [ -d "$ARG" ]; then
	#loop over data directory looking for dv files
	for f in $ARG/*.dv
	do
	if [[ $f != *"SIR"* ]]	# make sure they are not reconstructions
	then
		for o in $OTF_DIR/488*.otf
		do
		./sir.sh -i $f -o $o
		done
	fi
	done
elif [ -e "$ARG" ]; then
	if [[ $ARG != *"SIR"* ]] # make sure they are not reconstructions
	then
		for o in $OTF_DIR/488*.otf
		do
		./sir.sh -i $ARG -o $o
		done
	fi
else
	echo "first argument must either be a file or a directory of raw data"
fi



