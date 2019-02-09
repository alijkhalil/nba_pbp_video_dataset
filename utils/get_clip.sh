#!/bin/sh

#Check arguments
if [ $# -ne 2 ]; then
	echo "Must supply a URL pointing to the mp4 file and directory to place the file (in that order)."
	exit 1
fi

#Get filename
FILENAME="low_res.mp4"

echo "$1" | grep -q "768x432_1500"
if [ $? -eq 0 ]; then
	FILENAME="high_res.mp4"
fi

#Get mp4 clip
wget --timeout=45 --tries=18 --retry-connrefused -O "$2/$FILENAME" $1 2>/dev/null 

#Check that the file is actually an mp3
file "$2/$FILENAME" | grep -q "MP4"
if [ $? -eq 1 ] && [ "x$2" != "x" ]; then
	rm -f `find $2 -maxdepth 1 -type f`
	exit 1
fi


#Return success
exit 0