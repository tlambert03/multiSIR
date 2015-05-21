function evaluate() {
	FOLDER=$1
	#find $FOLDER -name \*SIR_log* | xargs grep "Amplitude" | awk '{print $1,$8,$9;}'
	ARR=( echo $(find $FOLDER -name \*SIR_log* | xargs -P4 grep "Amplitude" | awk '{print $9;}') )
	#echo ${ARR[*]}
	N=$(expr ${#ARR[@]} - 1)
	SCORES=()
	for i in $(seq 1 3 $N); do 
		a=$(expr $i)
		b=$(expr $i + 1)
		c=$(expr $i + 2)
		SUM=$(echo "${ARR[a]/,/} + ${ARR[b]/,/} + ${ARR[c]/,/}" | bc)
		AVG=$(printf %.4f $(echo "$SUM/3" | bc -l ) )
		SCORES+=($AVG);
		echo $AVG
	done
}

evaluate $1