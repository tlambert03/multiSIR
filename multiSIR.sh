#!/bin/bash

ARG=$1
OTF_DIR='/data1/OTFs/CORRECTED/'
COL=$2

#check if first argument is directory

if [ -d "$ARG" ]; then
	#loop over data directory looking for dv files
	for f in $ARG/*.dv
	do
	if [[ $f != *"SIR"* ]]	# make sure they are not reconstructions
	then
		for o in $OTF_DIR/$COL*.otf	#only corrected OTFS
		do
		./sir.sh -i $f -o $o
		done
	fi
	done
elif [ -e "$ARG" ]; then
	if [[ $ARG != *"SIR"* ]] # make sure they are not reconstructions
	then

		for o in $OTF_DIR/$COL*.otf 	#ONLY corrected OTFS
		do
			./sir.sh -i $ARG -o $o
		done

	fi
else
	echo "first argument must either be a file or a directory of raw data"
fi



