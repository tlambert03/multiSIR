 #!/bin/bash

###### CONSTANTS #######

#PRIISM_LIB='/usr/local/omx/priism/Priism_setup.sh'
PRIISM_LIB='/Users/talley/Dropbox/NIC/software/priism-4.4.1/Priism_setup.sh'
OTF_DIR='/data1/OTFs/CORRECTED'
SIR_SCRIPT='/home/worx/scripts/sir.sh'

# default values
OTFAGE=730 # max age of OTF: two years old
OTFNUM=100 # max number of OTFs to process (for each channel)
MAXT=1  # default to reconstructing only the single timepoint
WIENER=0.0010
BACKGROUND=80

###### FUNCTIONS #######

function OTFkey() {
    #generate OTF key
    local OTF=$1
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
    local KEY=$1
    local OTF_WAVE=$(echo $KEY | cut -c2-4);
    local OTF_DATE=$(echo $KEY | cut -c6-11);
    local OTF_OIL=15$(echo $KEY | cut -c13-14);
    local OTF_MEDIUM="glyc";
    local OTF_ANGLE=a$(echo $KEY | cut -c16-16);
    local OTF_BEAD=00$(echo $KEY | cut -c18-20);
    echo "${OTF_WAVE}_${OTF_DATE}_${OTF_OIL}_${OTF_MEDIUM}_${OTF_ANGLE}_${OTF_BEAD}.otf"
}

function multiSIR() {
	local ARG=$1
	local W=${OTFWAV:-$2}

    #if dv file, reconstruct multi
    if [ -e "$ARG" ] && [[ $ARG != *"SIR"* ]] && [[ $ARG == *.dv ]]; then

        # using xargs to parallelize reconstruction to take advantage of multiple cores
        find $OTF_DIR -mtime -$OTFAGE -name \\"$W"* | sort -n | head -$OTFNUM | xargs -n1 -P4 -I % $SIR_SCRIPT -i $ARG -o % -b $BACKGROUND -w $WIENER

        #local B=${ARG##*/}
        #local FNAME=${B%.*}
        #old method, without parallelization
        #	for OTF in $OTF_DIR/$W*.otf     #ONLY corrected OTFS
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
        echo "file ${ARG} does not appear to be a raw SIM .dv file..."
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
    local IN=$1
    local B=${IN##*/}

    for w in $WAVES; do
    	echo "copying channel ${w}..."
        local CPY=${OUTPUT_DIR}/${B/.dv/_$w.dv}
        # make a duplicate file containing just one of the wavelengths
        CopyRegion $IN $CPY -w=$w &
    done
    wait
}

function show_help {
    echo "Options:" 
    echo "      -h    show this help message" 
    echo "      -d    Set max age of OTF file in days old (default 730)" 
    echo "      -n    Set max number of OTF files used (default 100)" 
    echo "      -w    Force program to use specified OTF wavelength (don't match waves)"
    echo "      -c    Only process specified wavelength from multi-channel input file"
    echo "      -t    Number of timepoints to include in reconstructions (default 1)"
    echo "      -w    Wiener filter for reconstructions (default 0.001)"
    echo "      -b    Background for reconstructions (default 80)"
    exit 1;
} 

###### MAIN PROGRAM #######


while getopts ":hd:n:w:c:t:v:" flag; do
case "$flag" in
    h) show_help;;
    d) OTFAGE=$OPTARG;;
    n) OTFNUM=$OPTARG;;
    w) OTFWAV=$OPTARG;; # override default OTF->wavelength matching behavior
    c) CHANNEL=$OPTARG;; # do specified channel only
    t) MAXT=$OPTARG;;
    v) WIENER=$OPTARG;;
    b) BACKGROUND=$OPTARG;;
    \?) echo "Invalid option: -$OPTARG"; exit 1;
esac
done

if [ -n "$OTFWAV" ] && [ $OTFWAV -ne 435 ] && [ $OTFWAV -ne 477 ] && [ $OTFWAV -ne 528 ] && [ $OTFWAV -ne 541 ] && [ $OTFWAV -ne 608 ] && [ $OTFWAV -ne 683 ];
then
    echo "The OTF override (-w) was not one of the available options (435,477,528,541,608,683)"; exit 1;
fi

if [ -n "$CHANNEL" ] && [ $CHANNEL -ne 435 ] && [ $CHANNEL -ne 477 ] && [ $CHANNEL -ne 528 ] && [ $CHANNEL -ne 541 ] && [ $CHANNEL -ne 608 ] && [ $CHANNEL -ne 683 ];
then
    echo "The channel override (-c) was not one of the available options (435,477,528,541,608,683)"; exit 1;
fi

# priism library required

if [ ! -f $PRIISM_LIB ]; then
    echo "Priism Library not found!"
    echo "Please correct path in testSIR.sh"
    exit 1;  
else
    source $PRIISM_LIB;
fi

INPUT=${@:$OPTIND:1} # input file

if [ ! -f $INPUT ] || [ -z "$VAR" ]; then
    echo "Input file not found... Please enter filepath to test:"
    read INPUT
    if [ ! -f $INPUT ]; then
        echo "Input still no good... quitting"
        exit 1; 
    fi 
fi


RAW_FILE=$(readlink -f $INPUT)

# detect input file dimensions
NUMWAVES=$(numwaves $RAW_FILE)
WAVES=$(waves $RAW_FILE)
NUMTIMES=$(numtimepoints $RAW_FILE)

# create output directory
INPUT_DIR=${RAW_FILE%/*}
BASENAME=${RAW_FILE##*/}
FNAME=${BASENAME%.*}
OUTPUT_DIR="${INPUT_DIR}/${FNAME}_TEST"
mkdir -p $OUTPUT_DIR

# test for timelapse first
if [ $NUMTIMES -gt 1 ]; then
    echo "${NUMTIMES} timepoints... cropping to first timepoint"
    CPY="${OUTPUT_DIR}/${FNAME}_T1.dv"
    CopyRegion $RAW_FILE $CPY -t=1:${MAXT}:1;
    RAW_FILE=$CPY
fi


# then test for multiple channels
if [ $NUMWAVES -gt 1 ]; then

    # single channel override set
    if [ -n "$CHANNEL" ]; then

        echo "Single-wave override: only copying channel ${CHANNEL}"
        CPY=${OUTPUT_DIR}/${BASENAME/.dv/_$CHANNEL.dv}
        # make a duplicate file containing just one of the wavelengths
        CopyRegion $RAW_FILE $CPY -w=$CHANNEL
        multiSIR $CPY $CHANNEL

    else

        # SPLIT FILE INTO WAVELENGTHS
        echo "splitting file into ${NUMWAVES} wavelengths: ${WAVES}"
        splitFile $RAW_FILE;

        # RECONSTRUCT EACH WAVELENGTH
        for w in $WAVES; do
            CPY=${OUTPUT_DIR}/${BASENAME/.dv/_$w.dv}
            echo "reconstructing the crap out of wavelength ${w}..."
            multiSIR $CPY $w
        done

    fi


else

    # SINGLE-CHANNEL FILE
    ln -s $RAW_FILE $OUTPUT_DIR/$BASENAME
    multiSIR $OUTPUT_DIR/$BASENAME $WAVES

fi

