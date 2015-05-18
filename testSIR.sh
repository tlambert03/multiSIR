 #!/bin/bash

source /usr/local/omx/priism/Priism_setup.sh
OTF_DIR='/data1/OTFs/CORRECTED'

function OTFkey() {
    #generate OTF key
    OTF=$1
    OTF_NAME=${OTF##*/}
    OIFS=$IFS;
    IFS="_";
    keyArray=(${OTF_NAME%.otf});
    OTF_WAVE=${keyArray[0]};
    OTF_DATE=${keyArray[1]};
    OTF_OIL=${keyArray[2]};
    OTF_MEDIUM=${keyArray[3]};
    OTF_ANGLE=${keyArray[4]};
    OTF_BEAD=${keyArray[5]};
    IFS=$OIFS;
    OTF_KEY="w${OTF_WAVE}d${OTF_DATE}o${OTF_OIL: -2}${OTF_ANGLE}b${OTF_BEAD: -2}"
    echo $OTF_KEY
}

function OTFdecode() {
    #decode OTF key
    KEY=$1
    OTF_WAVE=$(echo $KEY | cut -c2-4);
    OTF_DATE=$(echo $KEY | cut -c6-11);
    OTF_OIL=15$(echo $KEY | cut -c13-14);
    OTF_MEDIUM="glyc";
    OTF_ANGLE=a$(echo $KEY | cut -c16-16);
    OTF_BEAD=00$(echo $KEY | cut -c18-20);
    echo "${OTF_WAVE}_${OTF_DATE}_${OTF_OIL}_${OTF_MEDIUM}_${OTF_ANGLE}_${OTF_BEAD}.otf"
}


function multiSIR() {
	ARG=$1
	COL=$2

	B=${ARG##*/}
	FNAME=${B%.*}


       # get wavelength of file)

    #if dv file, reconstruct multi
    if [ -e "$ARG" ] && [[ $ARG != *"SIR"* ]] && [[ $ARG == *.dv ]]; then

	find $OTF_DIR -mtime -$OTFAGE -name \\"$COL"* | xargs -n1 -P4 -I % ./sir.sh -i $ARG -o % -a $OPTIONS

#old method, without parallelization
#	for OTF in $OTF_DIR/$COL*.otf     #ONLY corrected OTFS
#	do
#	
#	OTF_KEY=$(OTFkey $OTF)
#	
#	OUTPUT_FILE="${OUTPUT_DIR}/${FNAME}_${OTF_KEY}_SIR.dv"
#	echo "OTF: ${OTF} (key:${OTF_KEY})"
#
#	./sir.sh -i $ARG -o $OTF -p $OUTPUT_FILE -a $OPTIONS;
#	done


    else
        echo "input file ${ARG} does not appear to be raw SIM data... recheck input"
    fi
}

function waves() {
    echo "$(echo | header $1 | grep "Wavelengths (nm)" | awk -F'   ' '{print $2}')"
}

function numwaves() {
    echo "$(echo | header $1 | grep "Number of Wavelengths" | awk -F'    ' '{print $2}')"
}

function numtimepoints() {
    echo "$(echo | header $1 | grep "Data Organization" | tail -c 4)" | xargs
}


function splitFile() {

    IN=$1
    B=${IN##*/}
    FNAME=${B%.*}
    WAVES=$(waves $IN)

    for w in $WAVES; do
	echo "copying channel ${w}..."
        CPY=${OUTPUT_DIR}/${B/.dv/_$w.dv}
        # make a duplicate file containing just one of the wavelengths
        CopyRegion $IN $CPY -w=$w &
    done
    wait

}


RAW_FILE=$1 # the grabs the input file
OTFAGE=${2:-365}
OPTIONS=$3
NUMWAVES=$(numwaves $RAW_FILE)
WAVES=$(waves $RAW_FILE)
NUMTIMES=$(numtimepoints $RAW_FILE)


DATA_DIR=${RAW_FILE%/*}
BASE_FILE=${RAW_FILE##*/}
FNAME=${BASE_FILE%.*}
OUTPUT_DIR="${DATA_DIR}/${FNAME}_TEST"

mkdir $OUTPUT_DIR

# test for timelapse first
if [ $NUMTIMES -gt 1 ]; then
    echo "${NUMTIMES} timepoints... cropping to first timepoint"
    CPY="${OUTPUT_DIR}/${FNAME}_T1.dv"
    CopyRegion $RAW_FILE $CPY -t=1:1:1;
    RAW_FILE=$CPY
fi


if [ $NUMWAVES -gt 1 ]; then

    ###############################
    # SPLIT FILE INTO WAVELENGTHS #
    ###############################

    echo "splitting file into ${NUMWAVES} wavelengths: ${WAVES}"
    splitFile $RAW_FILE;

    ###############################
    # RECONSTRUCT EACH WAVELENGTH #
    ###############################

    for w in $WAVES; do
        CPY=${OUTPUT_DIR}/${BASE_FILE/.dv/_$w.dv}
	echo "reconstructing the crap out of wavelength ${w}..."
        multiSIR $CPY $w
    done


else

    # SINGLE-CHANNEL FILE #

    multiSIR $RAW_FILE $WAVES

fi


