
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
    KEY=$1
    OTF_WAVE=$(echo $KEY | cut -c2-4);
    OTF_DATE=$(echo $KEY | cut -c6-11);
    OTF_OIL=15$(echo $KEY | cut -c13-14);
    OTF_MEDIUM="glyc";
    OTF_ANGLE=a$(echo $KEY | cut -c16-16);
    OTF_BEAD=00$(echo $KEY | cut -c18-20);
    echo "${OTF_WAVE}_${OTF_DATE}_${OTF_OIL}_${OTF_MEDIUM}_${OTF_ANGLE}_${OTF_BEAD}.otf"
}