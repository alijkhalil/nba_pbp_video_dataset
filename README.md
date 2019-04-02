High level overview:

	This repo is designed to provide a set of scripts for concurrently downloading 
	a huge dataset of short (e.g. 5-15 second) clips of individual NBA plays.
	It queries the NBA Stats website for every play over the past several NBA seasons
	and then also gets the label associated with each of those plays.  The plays are 
	organized using directories for each event.  In those diretories, they contain 
	a high and low resolution clip of each event and an XML file with information 
	on the video (including the player/players involved in the activity, the type 
	of activity, and the time of the activity in the context of the match).

	Overall, the dataset is quite large (e.g. several TBs) and may not fit on a single 
	drive.  (So, it may be useful to leverage the information below to modify the main 
	download script to work in shards.)  The substanial quantity of videos in this NBA 
	dataset make it unique because many other video dataset for training deep learning 
	models are relatively small.  Its large assortment of videos also forces the model 
	to distinguish between semantically different actions appearing visually similar.  
	A significant number of other video datasets do not provide this kind of visual 
	similarity between disparate actions and therefore can be solved with simple 
	modifications to pre-existing image processing CNNs.


Requirements (with location to find each one):

	1.  git  (needed to get this repo)
		-can be installed using system package manager (e.g. yum or apt)
	2.  JDK  (needed to build and run rhino Javascript engine)
		-can be installed using system package manager (e.g. yum or apt)
	3.  rhino  (javascript engine)
		-go to "https://github.com/mozilla/rhino" for source code
	4.  ffmpeg  (package containing 'ffmpeg' utility)
		-go to "https://www.ffmpeg.org/download.html" for source code
		-may also require yasm and/or nasm packages (found using system package manager)
	5.  procmail  (package containing 'lockfile' utility)
		-can be installed using system package manager (e.g. yum or apt)
	6.  xmlstarlet  (needed for processing/validating XML)
		-can be installed using system package manager (e.g. yum or apt)


Set-up instructions (in order):

	-SOCKS proxy for performing download on a cloud platform (optional)
		-background/motivation
			-NBA seems to blacklist certain cloud provider IPs
				-presumably to reduce stress on their web infrastructure
			-since users of this repo are generally individuals with local access to the NBA Stats website, 
				it is possible to set up a SOCKS proxy on a local machine for the AWS instance 
				to use in querying the NBA API endpoints needed to obtain this dataset
			-for that reason, this repo contains the 'start_and_monitor_socks' script to set-up a SOCKS proxy 
				-between a local machine and a remote instance (on a cloud provider)
		-steps
			-clone this repo onto a local Linux machine/VM
			-copy over the private key for accessing your cloud provider instance/machine
				-for the sake of this example, the key is called 'aws_admin_key.pem' and is in 'aws_key_dir'
			-create a key pair for accessing the local machine
				-commands:
					$ cd ~/aws_key_dir
					$ ssh-keygen -t rsa
						Generating public/private rsa key pair.
						Enter file in which to save the key (/home/jado/.ssh/id_rsa): /home/<username>/aws_key_dir/id_rsa
						Enter passphrase (empty for no passphrase): [Press enter]
						Enter same passphrase again: [Press enter]
					$ cat id_rsa.pub >> ~/.ssh/authorized_keys
					$ sudo systemctl reload sshd.service
			-get IP address for your cloud provider instance
			-run command for starting SOCKS proxy (on local machine/VM)
				$ nohup ./start_and_monitor_socks.bash id_rsa aws_admin_key.pem <aws_instance_ip> &
		-end result
			-the local machine will have two services:
				-one listening on port 9999
					-will forward any incoming connection to the correct port at destination
				-one reverse SSH connection
					-connecting the remote machine's port 9998 to the local machine's port 9999
			-the remote cloud instance will have one service:
				-the SSH connection on port 9998 forwarding traffic to local machine
		-notes
			-the specific ports to use on each machine can be modified in the 'start_and_monitor_socks' script
				-also requires the same changes on the 'kill_proxy' script
			-if the ports are changed, this should be reflected in the usage of any other scripts requiring the SOCKS port as input
				-like the 'start_X_download_processes' script
			
	-Java/JDK set-up
		-two options for installation:
			-try to use system default java
				-get system's location of default java binary
					$ whereis java
				-if not there or does not work in build process, you'll need to use system package manager
			-use system package manager to install appropriate version of JDK (likely v1.8.0)
		-after the install, you should find the 'java' binary	
			-commands
				-Red Hat/Fedora/CentOS
					-get full package name
						$ yum list installed | grep <jdk_version_number>
					-get directory containing java binary
						$ repoquery -l <package_name> | grep 'java$'
						-example: 
							$ repoquery -l java-1.8.0-openjdk-devel.x86_64 | grep 'java$'
				-Ubuntu
					-get full package name
						$ dpkg -l | grep <jdk_version_number>
					-get directory containing java binary
						$ dpkg-query -L <package_name> | grep 'java$'
						-example: 
							$ dpkg-query -L java-1.8.0-openjdk-devel.x86_64 | grep 'java$'
			-should note that JAVA_HOME needs to be set to the high level directory with 'lib' and 'bin'
				-one level up from bin
				-example:
					$ export JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk.x86_64
		
	-Rhino set-up
		-get rhino git repo from online
			-https://github.com/mozilla/rhino
		-run two commands (from root rhino repo directory) to build rhino library (after setting JAVA_HOME)
			$ ./gradlew jar
			$ ./gradlew test
		-find rhino jar file 
			-likely in the "<root_rhino_repo_dir>/buildGradle/libs" dir
		-set RHINO_LIB_DIR to absolute path of directory containing jar file 
			-example:
				$ export RHINO_LIB_DIR=/home/ec2-user/rhino/buildGradle/libs
		-within that directory, make a symlink for full rhino jar name to point to 'rhino.jar'
			$ ln -s $RHINO_LIB_DIR/rhino-1.7.11-SNAPSHOT.jar $RHINO_LIB_DIR/rhino.jar

		
Example command sequence to start the download process (after completing set-up):

	$ export JAVA_HOME=/usr/lib/jvm/jre-<jdk_version>-openjdk.x86_64   # 1.8.0 is recommended the JDK version number
	$ export RHINO_LIB_DIR=/home/<username>/rhino/buildGradle/libs
	$ ./start_X_download_processes.bash <num_download_processes> [<optional_local_SOCKS_port>]


Files under the hood:
	
	-./
		-./start_X_download_processes.bash
			-main script to begin entire download process
			-as noted above, accepts two parameters (in order):
				-the number of desired concurrent download processes
				-an optional parameter for the port of the SOCKS proxy (if one is needed on a cloud platform)
		-download_nba_clips.js
			-main routine and core source code for collecting the NBA event dataset
			-gets all available games from past several seasons
			-randomly iterate through each one and do the following:
				-ensure that no other thread is/has already looked at that particular game
				-get json object corresponding to the game play-by-play info
				-for each event in a game:
					-get event UUID
						-using get_event_UUID(cur_game_id, event_i)
					-create XML file to label each event and associated video
						-using 'get_event_XML_string' call
					-attempt to download video files for every event
					-mark the event as complete
						-using an empty 'done' file in the event's directory
		-start_delayed_process.bash
			-script to actually execute the 'download_nba_clips' script
				-called by the 'start_X_download_processes' script
			-uses java and rhino as its core technologies to do that
		-monitor_timeout.bash
			-script watching the progress of the threads collecting data 
				-called by the 'start_X_download_processes' script		
			-check for any stalls in downloads
				-presumably due to request throtling by NBA website
			-if there is any halt in progress, the threads/connections will be killed and then restarted
				-after a reasonable delay of course
		-stop_download.sh
			-script taking no parameters for immediately stopping all download processes
            -should be noted that the there may be outstanding web request for the next 10 minutes or so
	-utils/
		check_reverse_tunnel.sh
			-looks for service listening on specific port
			-in this case, it is used to forward traffic to avoid IP restrictions by NBA
		-check_if_game_being_processed.sh
			-looks for event ID of a particular game in all the other threads' log files
		-get_json.sh
			-runs CURL command to a JSON object as its output
		-get_xml.sh
			-runs CURL command to a XML hypertext as its output
		-get_clip.sh
			-takes the URL of the mp4 video and directory to place the video
			-depending on URL of video filename will be either "low_res.mp4" or "high_res.mp4"
		-remove_partial_downloads.bash
			-script to remove mp4 files that were likely only partially downloaded
			-will be run automatically by the 'monitor_timeout.bash' script during the download
	-proxy_set_up/
		-start_and_monitor_socks.bash
			-script to be run on a local machine (outside AWS or other cloud provider)
			-requires three parameters (described in the SOCKS set-up section above)
			-will connect remote instance to local machine and have local machine act as SOCKS proxy
			-if proxy connect ever goes down, the script will continually attempt to re-establish the proxy
		-kill_proxy.bash  
			-script to be run on a local machine (outside AWS or other cloud provider)
			-will kill the proxy connection between local machine and remote instance
			
			
Resulting dataset format:

	game_events/
	game_events/<nba_game_id>
	game_events/<nba_game_id>/done   (indicates entire game finshed downloading)
	game_events/<nba_game_id>/check_complete   (indicates entire game's mp4 files were validated)
	game_events/<nba_game_id>/<event_id>
	game_events/<nba_game_id>/<event_id>/high_res.mp4
	game_events/<nba_game_id>/<event_id>/low_res.mp4
	game_events/<nba_game_id>/<event_id>/event.xml
	game_events/<nba_game_id>/<event_id>/done   (indicates individual event files finished downloading)
    
    
Information in "event.xml" files:

	-videoLink
		index 0: 
			-high resolution video URL 
		index 1: 
			-low resolution video URL 
	-label
		-index 0:
			-event name
				-either TIP, 2PT (e.g. made 2PT), 3PT (e.g. made 3PT), 
							FGA (e.g. missed FGA), ASSIST, 
							REBOUND, TURNOVER, STEAL, FOUL, 
							BLOCK, FOULUNIQUE (e.g. technical)
			-jersey color
				-HOME OR AWAY
			-jersey number
				-maximum of 2 digit number
			-quarter of event
				-either 1, 2, 3, or 4
			-minute of event (remaining in quarter)
				-between 0 and 12, inclusive
			-second of event
				-between 0 and 59, inclusive
		-index N: 
			-same as format index 0
			-used if a single video corresponds to 2+ events (e.g. an ASSIST on a 2PT)
			-videos can have at most 3 labels in theory
				-in practice, they seem to actually have at most 2 labels

                
Resulting progress logs:

    logs/
    logs/thread<thread_id>.txt
        -contains the gameID's being handled by that specific process ID
        -designed so each process only downloads 1/<num_threads> of the total games in the dataset
    logs/monitor_log.txt
        -shows overall speed of download (over 7.5 minute intervals)
        -indicates if/when the download was stopped and then restarted due to throttling by NBA servers

        
Side notes/known issues:
	
	-only four scripts should need to be run directly by the user:
		-start_X_download_processes.bash
			-main script calling the neccessary underlying for downloading the dataset
        -stop_download.sh
            -script to kill all download processes immediately
		-proxy_set_up/start_and_monitor_socks.bash
			-on a local machine to set up a SOCK proxy for the remote cloud instance
		-proxy_set_up/kill_proxy.bash
			-on a local machine to terminate proxy connection with the remote cloud instance
    -final dataset is quite large (e.g. several TBs)
        -however, it is possible to simply kill the download process to only get a subset of the NBA games
            -using the 'stop_download.sh' file
        -at any point, the download can be resumed from the point that it was previously stopped
            -with the typical 'start_X_download_processes.bash' script
    -download process starts very slow and then proceeds to get significantly faster
        -this characteristic is a result of the jersey number cache having almost every player
        -after a download process has hit 40+ games, it will have hit nearly all players over the past two seasons
	-some videos are simply a clip of static images of an NBA logo
        -these video have been almost entirely eliminated from the dataset
            -by blacklisting video UUIDs having been used for 5+ events
        -method of blacklisting works very well in practice
            -however frame-by-frame comparison (at two arbitary points in the video) would be better
	-the repo would be cleaner/better in another more versatile/robust scripting language like Python
        -benefits would include:
            -not needing underlying shell scripts
            -likely perform necessary input validation for networking functionality under the hood
            -have less esoteric dependencies and therefore be more stable
        -if it turns out that this dataset becomes somewhat popular, then it will be modified to use Python
            -rather than its current "rhino/javascript" based core engine
	-script leverages NBA Stat's non-public API, so it is suspectible to any changes on the NBA's end
        -these changes could cause the script to stop working
        -initially, this dataset was acquired in 2016 and since then, NBA API has already altered its API
            -badly broke the initial download scripts
	-NBA Stats website known to throttle traffic and limit access from certain IPs
        -unforunately this throttling severe limits the maximum possible download speed
        -therefore may require using proxy scripts to perform download on cloud platform like AWS
        -throttling of traffic is monitored by the 'monitor_timeout.bash' script
	-download script uses template URLs filled by minimally sanitized information from the NBA website
        -in the unlikely event the NBA has malicious entries in its database, it could maybe trigger command execution
        -however, entries are currently stripped of all non-alphanumeric characters (excluding '-')
            -so it should make an issue with malicous input much less likely
        -for script to be fully immune to command injection attack further validation is probably needed
			-even better, script should ideally use built-in functionality for sending/recieving web request        
	-there is a minor flaw in the download process where it can only get a single jersey number per player per season
        -for instance, if a player was traded, the script will only be able to find his last team/jersey number
        -in practice, this doesn't matter because there are rarely ever important NBA players moved at the deadline