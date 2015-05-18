 #!/bin/bash

 # this script simple accepts the input file and seperates it into
 # single-wavelength images, appending the wavelength to the file name

RAW_FILE=$1

waves() {
    echo "$(echo | header $RAW_FILE | grep "Wavelengths (nm)" | awk -F'   ' '{print $2}')"
}

WAVES=$(waves $RAW_FILE)

for w in $WAVES; do
    CPY=${RAW_FILE/.dv/-$w.dv}
    # make a duplicate file containing just one of the wavelengths
    CopyRegion $RAW_FILE $CPY -w=$w;
done