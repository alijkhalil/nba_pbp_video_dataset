#!/bin/bash

cd `dirname $0`
LABELS_DIR="./../game_events"
CHECK_DONE_FILENAME="check_complete"

echo "Deleting all likely partial downloads."
echo -e "Keep in mind that this process will take a while...\n"


# Go through unchecked videos
for dirname in `find $LABELS_DIR -maxdepth 1 -type d | grep -v events$`; do 
    if [ \( ! -f $dirname/$CHECK_DONE_FILENAME \) -a \( -f $dirname/done \) ]; then
        MP4_FILES=`find $dirname -name \*mp4`
        
        for vid_path in $MP4_FILES; do
            if [ -f $vid_path ]; then
                ERROR_VAL=`ffmpeg -v error -i $vid_path -f null - 2>&1 | wc -l`

                # Delete entire game event directory with incomplete videos     
                file $vid_path | grep -i MP4 > /dev/null 2>&1
                if [ \( $? -ne 0 \) -o \( $ERROR_VAL -ne 0 \) ]; then
                    RM_FILE_DIR=`dirname $vid_path`
                    
                    if [ -f $RM_FILE_DIR/done ]; then
                        RM_FILES=`find $RM_FILE_DIR -type f | grep -v done`
                        
                        if [ $? -eq 0 ]; then     
                            echo "Removed contents of $RM_FILE_DIR directory."
                            rm -f $RM_FILES
                        fi
                    fi
                fi
            fi
        done
        
        touch $dirname/$CHECK_DONE_FILENAME
    fi
done


# Exit successfully
echo "Done!"
exit 0
