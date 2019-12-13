#!/bin/bash

FPATH="$HOME/os/FlameGraph/"
FPERF="`dirname $0`/perf-output/"
PERF_SCRIPT_CMD="perf script"
PERF_REPORT=""
GREP_STRINGS=""
KERNEL_VERSION=""
SYMFS=""
TAR=false
DATE=$(date +%Y-%m-%d_%H:%M:%S)

while getopts "g:i:k:s:th" opt; do
    case $opt in
        g) GREP_STRINGS=$OPTARG ;;
        i) PERF_REPORT=$OPTARG ;;
        k) KERNEL_VERSION=$OPTARG ;;
        s) SYMFS=$OPTARG ;;
        t) TAR=true ;;
        h|*)
            echo "usage: $0 -g <grep string to make specific flamegraph> -i <perf file> -k <kernel version #>"
            echo "	i - perf report file"
            echo "	k - kernel version - specific kernel version number"
            echo "	g - grep strings - to grep specific strings e.g., kworker, to make flamegraph"
            echo "	s - symfs - to assign the directory to search for the debug symbol of kernel modules"
            echo "	t - tar the $FPERF"
            exit 0
            ;;
    esac
done

# check if the command line has assign the perf.data file. e.g. '-i xxx.perf.data'
if [ ! -e "$PERF_REPORT" ]; then
    # if command didn't assign the perf data, go ahead to check the current folder
    echo "File doesn't exist: $PERF_REPORT!!"
    if [ -e "`dirname $0`/perf.data" ]; then
        echo "Do you mean the `dirname $0`/perf.data?"
    fi
        echo "Please use -i to append the perf.data"
        echo "usage: $0 -g <grep string to make specific flamegraph> -i <perf file> -k <kernel version #>"
        echo "	i - perf report file"
        echo "	k - kernel version - specific kernel version number"
        echo "	g - grep strings - to grep specific strings e.g., kworker, to make flamegraph"
        exit -1
fi

echo "Use the $PERF_REPORT as the source of the FlameGraph."

# check if the $PERF_REPORT is readable
if [ ! -r $PERF_REPORT ]; then
    echo "Permission denied: $PERF_REPORT cannot be read."
    echo "Try: \"sudo chmod a+r $PERF_REPORT\""
    exit -1
fi

# Try to clone the FlameGraph if it doesn't exist.
if [ ! -e $FPATH ]; then
    echo "Install the FlameGraph by the following instructions:"

    echo "mkdir -p $HOME/os/"
    mkdir -p $HOME/os/

    echo "git clone https://github.com/brendangregg/FlameGraph $HOME/os/FlameGraph"
    git clone https://github.com/brendangregg/FlameGraph $HOME/os/FlameGraph

    echo "Installation Success!"
fi

PSCRIPT="${FPERF}${DATE}.`basename ${PERF_REPORT}`.script"
PFOLDED="${FPERF}${DATE}.`basename ${PERF_REPORT}`.folded"
PSVG="${FPERF}${DATE}.`basename ${PERF_REPORT}`.svg"
PFOLDED_SUM="${FPERF}stack_sum"

# mkdir the folder to store the perf report data
mkdir -p ${FPERF}

# perf script -i ./perf-110417_201609 -k ~/ddebs/ddebs-4.4.0-53.74/usr/lib/debug/boot/vmlinux-4.4.0-53-generic > perf-110417_201609.perf
[[ $PERF_REPORT != "" ]] && PERF_SCRIPT_CMD="${PERF_SCRIPT_CMD} -i $PERF_REPORT"
[[ $KERNEL_VERSION != "" ]] && PERF_SCRIPT_CMD="${PERF_SCRIPT_CMD} -k $KERNEL_VERSION"
[[ $SYMFS != "" ]] && PERF_SCRIPT_CMD="${PERF_SCRIPT_CMD} --symfs $SYMFS"

# generate the perf script file for the stackcollapse to extract the call stack
${PERF_SCRIPT_CMD} > ${PSCRIPT}

# extract the call stack for the flamegraph.pl to generate the svg interactive graph
${FPATH}stackcollapse-perf.pl ${PSCRIPT} > ${PFOLDED}

# cat all the callgraph to make the summary
cat ${PFOLDED} >> ${PFOLDED_SUM}

if [[ $GREP_STRINGS == "" ]]; then
    cat ${PFOLDED} | ${FPATH}flamegraph.pl > ${PSVG}
else
    # add the string name to the SVG name to identify the file easily
    PSVG="${PFOLDED}S$GREP_STRINGS.svg"
    egrep $GREP_STRINGS ${PFOLDED} | ${FPATH}flamegraph.pl > ${PSVG}
fi

if $TAR; then
    tar zcvf ${PERF_REPORT}.tar.gz ${PERF_REPORT}* ${FPERF}
    echo "# The perf-related file: \"${PERF_REPORT}\" has been tared."
    echo "# The perf-related folder: \"${FPERF}\" has been tared."
    rm $(ls ${PERF_REPORT}* | grep -v tar.gz)
    echo "# Delete the related perf report files:" ${PERF_REPORT}*
fi

echo "###########"
echo "# The perf interactive .svg graph \"${PSVG}\" has been generated."
echo ""
echo "# The FlameGraph can be viewed by:"
echo "# $ google-chrome-stable ${PSVG}"
echo "# or"
echo "# $ firefox ${PSVG}"
echo "###########"
