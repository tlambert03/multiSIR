 #!/bin/bash

prii
OTF_DIR='/Users/talley/Dropbox/omx/data/testSIR/correctedOTFs'

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

    #check if directory
    if [ -d "$ARG" ]; then
        #loop over data directory
        for f in $ARG
        do
            multiSIR $f
        done

    #if dv file, reconstruct multi
    elif [ -e "$ARG" ]; then
        if [[ $ARG != *"SIR"* ]] && [[ $ARG == *.dv ]] # make sure they are not reconstructions
        then

            DATA_DIR=${ARG%/*}
            BASE_FILE=${ARG##*/}
            FNAME=${BASE_FILE%.*}

            mkdir ${DATA_DIR}/$FNAME

            # get wavelength of file)

            for OTF in $OTF_DIR/$COL*.otf     #ONLY corrected OTFS
            do

                OTF_KEY=$(OTFkey $OTF)

                OUTPUT_FILE="${DATA_DIR}/$FNAME/${FNAME}_${OTF_KEY}_SIR.dv"

                ./sir.sh -i $ARG -o $OTF -p $OUTPUT_FILE
            done

        fi
    else
        echo "first argument must either be a file or a directory of raw data"
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

    RAW_FILE=$1

    WAVES=$(waves $RAW_FILE)

    for w in $WAVES; do
        CPY=${RAW_FILE/.dv/-$w.dv}
        # make a duplicate file containing just one of the wavelengths
        CopyRegion $RAW_FILE $CPY -w=$w;
    done

}



RAW_FILE=$1 # the grabs the input file
NUMWAVES=$(numwaves $RAW_FILE)
WAVES=$(waves $RAW_FILE)
NUMTIMES=$(numtimepoints $RAW_FILE)

echo "testing ${RAW_FILE}..."


# test for timelapse first
if [ $NUMTIMES -gt 1 ]; then
    CPY=${RAW_FILE/.dv/_T1.dv}
    CopyRegion $RAW_FILE $CPY -t=1:1:1;
    RAW_FILE=$CPY
fi


if [ $NUMWAVES -gt 1 ]; then

    ###############################
    # SPLIT FILE INTO WAVELENGTHS #
    ###############################

    echo "splitting file into ${NUMWAVES} wavelengths: ${WAVES}"
    splitfile $RAW_FILE;

    ###############################
    # RECONSTRUCT EACH WAVELENGTH #
    ###############################

    for w in $WAVES; do
        CPY=${RAW_FILE/.dv/-$w.dv}
        multiSIR $CPY $w
    done


else

    # SINGLE-CHANNEL FILE #

    multiSIR $RAW_FILE

fi


