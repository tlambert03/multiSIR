#!/bin/bash

###### CONSTANTS #######

PRIISM_LIB='/usr/local/omx/priism/Priism_setup.sh'
#PRIISM_LIB='/Users/talley/Dropbox/NIC/software/priism-4.4.1/Priism_setup.sh'
OTF_DIR='/data1/OTFs/CORRECTED'
#OTF_DIR='/Users/talley/Dropbox/OMX/CORRECTED'
SIR_SCRIPT='/home/worx/scripts/sir.sh'

# default values
OTFAGE=730 # max age of OTF: two years old
OTFNUM=100 # max number of OTFs to process (for each channel)
MAXT=1  # default to reconstructing only the single timepoint
WIENER=0.0010
BACKGROUND=80
OILRANGE=4 # default OTF oil search range
OILCENTER=1516 # default OTF oil search center (restrict constructions to CENTER +/- RANGE)
        # script will try to parse OILCENTER from input filename, and fall back to this value ...
DRYRUN=0 # default to actually performing the reconstruction, flag -x will just output info

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


function rlinkf() {

    TARGET_FILE=$1

    cd `dirname $TARGET_FILE`
    TARGET_FILE=`basename $TARGET_FILE`

    # Iterate down a (possible) chain of symlinks
    while [ -L "$TARGET_FILE" ]
    do
        TARGET_FILE=`readlink $TARGET_FILE`
        cd `dirname $TARGET_FILE`
        TARGET_FILE=`basename $TARGET_FILE`
    done

    # Compute the canonicalized name by finding the physical path 
    # for the directory we're in and appending the target file.
    PHYS_DIR=`pwd -P`
    RESULT=$PHYS_DIR/$TARGET_FILE
    echo $RESULT

}


function multiSIR() {
	local ARG=$1
	local W=${OTFWAV:-$2}
    local OILMIN=$(echo $OILCENTER-$OILRANGE | bc )
    local OILMAX=$(echo $OILCENTER+$OILRANGE | bc )

    #if dv file, reconstruct multi
    if [ -e "$ARG" ] && [[ $ARG != *"SIR"* ]] && [[ $ARG == *.dv ]]; then

        if [ $DRYRUN -eq 1 ]; then 
            # using xargs to parallelize reconstruction to take advantage of multiple cores
            echo "--------------------------------------"
            echo "Dry Run - NO RECONSTRUCTIONS PERFORMED"
            echo "Input: $(basename $ARG)"
            echo "Background: ${BACKGROUND}"
            echo "Wiener: ${WIENER}"
            echo "OTF oil range: $OILMIN - $OILMAX"
            echo "OTF wavelength: $W"
            echo "OTFs that would be used:"
            find $OTF_DIR -mtime -$OTFAGE -name \\"$W"* | \
            awk -F'_' -v min=$OILMIN -v max=$OILMAX '{ if ($3 >=min && $3<=max) print}' | \
            sort -rn | \
            head -$OTFNUM
        else
            echo "reconstructing the crap out of wavelength ${W}..."
            # using xargs to parallelize reconstruction to take advantage of multiple cores
            find $OTF_DIR -mtime -$OTFAGE -name \\"$W"* | \
            awk -F'_' -v min=$OILMIN -v max=$OILMAX '{ if ($3 >=min && $3<=max) print}' | \
            sort -rn | \
            head -$OTFNUM | \
            xargs -n1 -P4 -I % $SIR_SCRIPT -i $ARG -o % -b $BACKGROUND -w $WIENER
        fi
        echo ""

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
    echo "MultiSIR OTF tester, version 0.1"
    echo ""
    echo "Usage:    testSIR [options] inputfile"
    echo "Example:  testSIR -n10 -c528 -b100 -t10 inputfile" 
    echo ""
    echo "Optional Flags:" 
    echo "   -h   Help         Show this help message" 
    echo "   -x   Dry Run      Perform a dry run: no reconstructions will be performed"
    echo "" 
    echo "Options that expect arguments:" 
    echo "   -d   Cap Age      Set max age of OTF file in days old (default 730)" 
    echo "   -n   Cap #OTFs    Set max number of OTF files used (default 100)" 
    echo "   -f   Force OTF    Force program to use specified OTF wavelength (don't match waves)"
    echo "   -c   SingleWave   Only process specified wavelength from multi-channel input file"
    echo "   -l   Oil Center   Only use OTFs with oil RI surrounding this input value"
    echo "   -o   Oil Range    Only use OTFs with oil RI +/- this input value"
    echo "                     (default center is 1.516 if not in file name)"
    echo "   -t   Timepoints   Number of timepoints to include in reconstructions (default 1)"
    echo "   -w   Weiner       Wiener filter for reconstructions (default 0.001)"
    echo "   -b   Background   Background for reconstructions (default 80)"
    echo ""
    echo "Channel Lookup Guide:" 
    echo "*channels must be expressed as emission wavelengths*"
    echo "    Ex -> Em  (BGR)       Ex -> Em  (CYR) "
    echo "   405 -> 435            445 -> 477  "
    echo "   488 -> 528            514 -> 541  "
    echo "   568 -> 608  "
    echo "   642 -> 683  "
    exit 1;
} 

###### MAIN PROGRAM #######

while getopts ":hxd:n:f:c:o:l:t:w:b:" flag; do
case "$flag" in
    h) show_help;;
    x) DRYRUN=1;;
    d) OTFAGE=$OPTARG;;
    n) OTFNUM=$OPTARG;;
    f) OTFWAV=$OPTARG;; # override default OTF->wavelength matching behavior
    c) CHANNEL=$OPTARG;; # do specified channel only
    o) OILRANGE=$OPTARG;;
    l) OILCENTER=$OPTARG;;
    t) MAXT=$OPTARG;;
    w) WIENER=$OPTARG;;
    b) BACKGROUND=$OPTARG;;
    \?) echo "Invalid option: -$OPTARG"; exit 1;
esac
done

if [ -n "$OTFWAV" ] && [ $OTFWAV -ne 435 ] && [ $OTFWAV -ne 477 ] && [ $OTFWAV -ne 528 ] \
    && [ $OTFWAV -ne 541 ] && [ $OTFWAV -ne 608 ] && [ $OTFWAV -ne 683 ];
then
    echo "The OTF override (-w) was not one of the available options (435,477,528,541,608,683)"; exit 1;
fi

if [ -n "$CHANNEL" ] && [ $CHANNEL -ne 435 ] && [ $CHANNEL -ne 477 ] && [ $CHANNEL -ne 528 ] \
    && [ $CHANNEL -ne 541 ] && [ $CHANNEL -ne 608 ] && [ $CHANNEL -ne 683 ];
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

if [ ! -f $INPUT ] || [ -z $INPUT ]; then
    echo "Input file not found..."
    read -e -p "Please enter new filepath: " INPUT
    if [ ! -f $INPUT ] || [ -z $INPUT ]; then
        echo "Input still no good... quitting"
        show_help;
    fi 
fi

echo ''


#RAW_FILE=$(readlink -f $INPUT)
RAW_FILE=$(rlinkf $INPUT)

# detect input file dimensions
NUMWAVES=$(numwaves $RAW_FILE)
WAVES=$(waves $RAW_FILE)
NUMTIMES=$(numtimepoints $RAW_FILE)

# create output directory
INPUT_DIR=${RAW_FILE%/*}
BASENAME=${RAW_FILE##*/}
FNAME=${BASENAME%.*}

# Try to find oil RI in the filename, looking for string between 1510_ and 1529_
OILCHECK=$(echo ${FNAME} | grep -E -o '15[12]\d_' | tr -d '_')
if [ ! -z $OILCHECK ] && [ $OILCHECK -lt 1525 ] && [ $OILCHECK -gt 1509 ]; then
    echo "found oil RI in filename: ${OILCHECK}"
    OILCENTER=$OILCHECK
else
    echo "oil RI not found in filename, centering around ${OILCENTER}"
fi


# create output directory
OUTPUT_DIR="${INPUT_DIR}/${FNAME}_TEST"
mkdir -p $OUTPUT_DIR


# test whether timelapse, if so crop to first timepoint (or MAXT specified by user)
if [ $NUMTIMES -gt 1 ]; then
    echo "${NUMTIMES} timepoints... cropping to first $MAXT timepoint(s)"
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
            multiSIR $CPY $w
            echo ""
        done

    fi


else

    # SINGLE-CHANNEL FILE
    echo "testing single wavelength file..."
    ln -s $RAW_FILE $OUTPUT_DIR/$BASENAME 2>/dev/null
    multiSIR $OUTPUT_DIR/$BASENAME $WAVES

fi

