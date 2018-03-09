#!/bin/bash -e

sort_report() {
	MODE=$1
	NAME=$2
	MODULE=$3
	IGREP=igreport_${NAME}.res
	IGSORT=igsorted_${NAME}_${MODULE}_${MODE}.res
	if [ "$MODE" == "self" ]; then
		awk -v module=${MODULE} 'BEGIN { total = 0; } { if(substr($0,0,1)=="["&&index($0,module)!=0) {print $0; total += $3;} } END { print "Total: "total } ' igreport_testNew.res | sort -n -r -k3 | awk '{ if(index($0,"Total: ")!=0){total=$0;} else{print $0;} } END { print total; }' > ${IGSORT} 2>&1
	elif [ "$MODE" == "desc" ]; then
		awk -v module=${MODULE} 'BEGIN { total = 0; } { if(substr($0,0,1)=="-"){good = 0;}; if(good&&length($0)>0){print $0; total += $3;}; if(substr($0,0,1)=="["&&index($0,module)!=0) {good = 1;} } END { print "Total: "total } ' ${IGREP} | sort -n -r -k1 | awk '{ if(index($0,"Total: ")!=0){total=$0;} else{print $0;} } END { print total; }' > ${IGSORT} 2>&1		
	fi
	echo "Produced ${IGSORT}"
}

EXE=""
NAME="test"
SORTSELF=()
SORTDESC=()
TARGET=""
ROOT=""
CMS=""

# todo: add mp, sqlite options
while getopts "e:n:t:s:d:rc" opt; do
	case "$opt" in
		e) EXE=$OPTARG
		;;
		n) NAME=$OPTARG
		;;
		t) TARGET="-t $OPTARG"
		;;
		s) IFS="," read -a SORTSELF <<< "$OPTARG"
		;;
		d) IFS="," read -a SORTDESC <<< "$OPTARG"
		;;
		r) ROOT=true
		;;
		c) CMS=true
	esac
done

# special CMS settings
if [ -n "$CMS" ]; then
	SORTDESC+=("doEvent")
	if [ -z "$TARGET" ]; then
		TARGET="-t cmsRun"
	fi
fi

if [ -z "$EXE" ] && [ ${#SORTSELF[@]} -eq 0 ] && [ ${#SORTDESC[@]} -eq 0 ]; then
	echo "-e or -s or -d required"
	exit 1
fi

if [ -n "$EXE" ]; then
	# special way to run a ROOT macro (otherwise difficult due to quote nesting)
	if [ -n "$ROOT" ]; then
		EXE="root.exe -b -l -q $EXE"
	fi

	IGNAME=igprof_${NAME}
	IGREP=igreport_${NAME}.res
	# subshell to log commands but avoid `set +x`
	(set -x;
	igprof -d $TARGET -pp -z -o ${IGNAME}.pp.gz ${EXE} > ${IGNAME}.log 2>&1;
	igprof-analyse -d -v ${IGNAME}.pp.gz > ${IGREP} 2>&1;
	)

	echo "Produced ${IGREP}"
fi

# find module contributions, make sorted list & total
for MODULE in ${SORTSELF[@]}; do
	sort_report self ${NAME} ${MODULE}
done
# find module descendants (e.g. producers/filters/analyzers descend from doEvent), make sorted list & total
for MODULE in ${SORTDESC[@]}; do
	sort_report desc ${NAME} ${MODULE}
done

