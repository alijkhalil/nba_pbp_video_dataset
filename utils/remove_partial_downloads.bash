#!/bin/bash

cd `dirname $0`
SCRIPT_DIR="./../game_events"

echo "Deleting all likely partial downloads."
echo -e "Keep in mind that this process will take a while...\n"


# Go through high resolution videos
MIN_NUM_BYTE=1100000
for high_res_vid in `find $SCRIPT_DIR -name high_res.mp4`; do
    NUM_BYTES=`ls -l $high_res_vid | awk '{print $5}'`
    
    # Delete entire game event directory with super small videos 
    file $high_res_vid | grep -i MP4 > /dev/null 2>&1
    if [ \( $? -ne 0 \) -o \( $NUM_BYTES -lt $MIN_NUM_BYTE \) ]; then
        RM_FILE_DIR=`dirname $high_res_vid`
        
        if [ -f $RM_FILE_DIR/done ]; then
            RM_FILES=`find $RM_FILE_DIR -type f | grep -v done`           
            
            if [ $? -eq 0 ]; then
                echo "Removed contents of $RM_FILE_DIR directory."
                rm -f $RM_FILES
            fi
        fi
    fi
done


# Go through low resolution videos
MIN_NUM_BYTE=400000
for low_res_vid in `find $SCRIPT_DIR -name low_res.mp4`; do
    NUM_BYTES=`ls -l $low_res_vid | awk '{print $5}'`
    
    # Delete entire game event directory with super small videos     
    file $low_res_vid | grep -i MP4 > /dev/null 2>&1
    if [ \( $? -ne 0 \) -o \( $NUM_BYTES -lt $MIN_NUM_BYTE \) ]; then
        RM_FILE_DIR=`dirname $low_res_vid`
        
        if [ -f $RM_FILE_DIR/done ]; then
            RM_FILES=`find $RM_FILE_DIR -type f | grep -v done`
            
            if [ $? -eq 0 ]; then     
                echo "Removed contents of $RM_FILE_DIR directory."
                rm -f $RM_FILES
            fi
        fi
    fi
done


# Exit successfully
echo "Done!"
exit 0
