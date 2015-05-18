#!/bin/bash


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


# default values
BACKGROUND=80
WIENER=0.0010

while getopts ":i:o:p:w:b:a:" flag; do
    case "${flag}" in
        i) INPUT_FILE=${OPTARG};;
        o) OTF=${OPTARG};;
        p) OUTPUT_FILE=${OPTARG};;
    	b) BACKGROUND=${OPTARG};;
    	w) WIENER=${OPTARG};;
    	a) ARGS=${OPTARG};;
    	\?) echo "invalid option specified";;
    esac
done
shift $((OPTIND-1))

if [ -z "$INPUT_FILE" ];
then
    echo "The input data file must be specified with the -i flag"; exit 1;
fi


if [ -z "$OTF" ];
then
    echo "The OTF file must be specified with the -o flag"; exit 1;
fi

if [ -z "$OUTPUT_FILE" ];
then
	DD=${INPUT_FILE%/*}
	BF=${INPUT_FILE##*/}
	FN=${BF%.*}
	otfk=$(OTFkey $OTF)
	OUTPUT_FILE="${DD}/${FN}_${otfk}_SIR.dv"
fi


if [ $( echo "$WIENER>1" | bc ) -eq 1 ] || [ $( echo "$WIENER>1" | bc ) -eq 1 ];
then
    echo "The wiener filter flag (-w) must be between 0 and 1"; exit 1;
fi

if [ $( echo "$BACKGROUND>32766" | bc ) -eq 1 ];
then
    echo "The background filter flag (-b) must be less than 32766"; exit 1;
fi

#computed varibles
DATA_DIR=${INPUT_FILE%/*}
BASE_FILE=${INPUT_FILE##*/}
OTF_NAME=${OTF##*/}
OTF_KEY=$(OTFkey $OTF)


# softWoRx Task Command File
export OMP_NUM_THREADS=8
export STATUS_FILE="${DATA_DIR}/${BASE_FILE%.dv}_${OTF_KEY}_status.txt"
export HOME=/home/worx
export LOGNAME=worx
export SW_BASE=/usr/local/softWoRx
export DV_BASE=/usr/local/softWoRx
export LD_LIBRARY_PATH=/usr/local/softWoRx/lib/i386


/usr/local/softWoRx/bin/i386/XYenhance3D.fftw \
  $INPUT_FILE \
  $OUTPUT_FILE \
  $OTF \
  -channel_k0 435 -0.831000 -1.884600 0.213000 \
  -channel_k0 528 -0.804300 -1.855500 0.238800 \
  -channel_k0 608 -0.775600 -1.826500 0.270100 \
  -channel_k0 683 -0.768500 -1.823400 0.276100 \
  -channel_ex_linespacing 405 0.1920 \
  -channel_ex_linespacing 488 0.2075 \
  -channel_ex_linespacing 568 0.2290 \
  -channel_ex_linespacing 642 0.2400 \
  -status_file $STATUS_FILE \
  -background $BACKGROUND \
  -wiener $WIENER  -linespacing 0.20800 -basek0guesses -0.796300 -1.843300 0.249300\
  $ARGS \
  &>"${DATA_DIR}/${BASE_FILE%.dv}_${OTF_KEY}_SIR_log.txt"

# Check exit status
if [ "$?" != "0" ]; then
exit 1
fi



#Usage:
#XYenhance3D [[input file] [output file] [OTF file]] [Options]
#
#Options:
#        -ndirs N -- number of directions in data (default is 3)
#        -nphases N -- number of phases in data (default is 5)
#        -skipchannel x -- x is a zero-based channel number to skip
#        -recalcarray -- how many times do you want to re-calculuate overlapping arrays (default is 1)
#        -inputapo N -- number of pixels to apodize the input data (-1 to cosine apodize)
#        -forcemodamp f1 f2 -- force the modulation amplitude to be f1 and f2
#        -nok0search -- do not want to search for the best k0
#        -refinek0alltimepoints -- refine k0 for all time points (default is use 1st time point only)
#        -noapodizeout -- do not want to apodize the output data
#        -triangleapo -- triangle apodize the output data
#        -nosuppress -- do not want to suppress singularity at OTF origins
#        -scratch -- to use scratch files as temporary storage
#        -noequalize -- no equalization of input data
#        -equalizeall -- to equalize images of all sections and directions
#        -wiener f -- set wiener constant to be f (default is 0.001)
#        -background f -- set the constant background intensity (default is 65)
#        -driftfix -- to estimate and then fix drift in 3D
#        -driftchannel -- specify which channel to use (default is first channel)
#        -2lenses -- to use double-lens algorithm
#        -usecorr -- to correct artifacts caused by CCD
#        -maxiter x -- the number of iterations in deconvolution
#        -numthreads x -- the maximum number of process threads to use
#        -linespacing f -- override default line spacing with this value
#        -correctNegativeIntensities -- shift all image intensities up so there are no negative intensities
#        -discardNegativeIntensities -- set all negative intensities to zero
#        -basek0guesses ang1 ang2 ang3 -- k0 guess angles for first or all channels (if none other are specified)
#        -channel_otf wavelength otf_file -- optional channel-specific OTF file
#        -channel_k0 wavelength k0_1 k0_2 k0_3 -- optional channel-specific k0 angles
#        -channel_bkg wavelength bkg_val -- optional channel-specific background values to subtract
#        -channel_wfilter wavelength wfilter_val -- optional channel-specific wiener filter constants
#        -channel_ex_linespacing wavelength f -- optional EX-channel-specific linespacing value
#        -status_file file -- status file for controlling program to watch
#        -help or -h -- print this message

#  -channel_k0 435 -0.831000 -1.884600 0.213000 \
#  -channel_k0 528 -0.804300 -1.855500 0.238800 \
#  -channel_k0 608 -0.775600 -1.826500 0.270100 \
#  -channel_k0 683 -0.768500 -1.823400 0.276100 \
#  -channel_k0 477 -0.803400 -1.856900 0.238900 \ 
#  -channel_k0 541 -0.798300 -1.849100 0.244700 \
#  -channel_ex_linespacing 405 0.1920 \
#  -channel_ex_linespacing 445 0.2035 \
#  -channel_ex_linespacing 488 0.2075 \
#  -channel_ex_linespacing 514 0.2200 \
#  -channel_ex_linespacing 568 0.2290 \ 
#  -channel_ex_linespacing 642 0.2400 \
