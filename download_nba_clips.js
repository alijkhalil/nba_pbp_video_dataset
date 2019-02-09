//Import Java packages
importClass(java.io.File)
importClass(java.io.FileWriter)


//Template strings and values
MAGIC_ERROR_STR="ERROR_JADO_123"

PBP_PLAYER_ID_KEY="pid"
PBP_OPP_PLAYER_ID_KEY="opid"
PBP_TEAMMATE_ID_KEY="epid"
PBP_TEAM_ID_KEY="tid"

JERSEY_NUM_INDEX=4
PLAYER_ID_INDEX=12

GAMES_ON_DAY_TEMPLATE_URL = "http://data.nba.net/10s/prod/v1/DATE_STR/scoreboard.json"
PBP_TEMPLATE_URL = "https://data.nba.com/data/10s/v2015/json/mobile_teams/nba/SEASON_VAL/scores/pbp/GAME_ID_full_pbp.json"
PLAYER_INFO_TEMPLATE_URL = "https://stats.nba.com/stats/commonteamroster?LeagueID=00&Season=SEASON_STR&TeamID=TEAM_ID_VAL"
EVENT_UUID_TEMPLATE_URL = "https://stats.nba.com/stats/videoevents?GameEventID=EVENT_ID_VAL&GameID=GAME_ID_VAL"
VID_UUID_XML_TEMPLATE_URL = "https://secure.nba.com/video/wsc/league/UUID_VAL.secure.xml"
  

//Global variables
NO_SOCK_PORT_NUM=-1
SOCKS_PORT_NUM=arguments[0]

PRINT_JSON_ERRORS=false
PRINT_BAD_UUIDS=true
MAX_ALLOWED_DUPS=5

JERSEY_NUM_LOOKUP = {}
REPEATED_UUIDS_NUM_LOOKUP = {}
UUID_COUNT_LOOKUP = {}

STATIC_VIDEO_UUID_BLACKLIST = [ "4549dfbf-fde2-4dcc-8065-afade5ada267" ]

BASE_DIR = arguments[1] + "/"
UTILS_DIR = BASE_DIR + "utils/"
DOWNLOADS_DIR = "game_events/"
DONE_FILE_NAME = "done"


//General functionality
function another_thread_taking_care_of_it(game_id) {
	feed = { output: '' }
	already_done = runCommand(UTILS_DIR + "check_if_game_being_processed.sh", game_id, feed)
	
	return already_done
}

//Eliminate non-alphanumeric or '-' character
function sanitize_input(str) {
	return str.toString().replace(/[^\-a-zA-Z0-9]/gi,'')	
}

function requires_socks() {
    return !(SOCKS_PORT_NUM == NO_SOCK_PORT_NUM)
}

function trim_preceeding_zeros(num_str) {
    while (num_str.length > 1) {
        if (num_str.charAt(0) == "0") {
            num_str = num_str.substring(1)
        } else {
            break
        }
    }
    
    return num_str
}

function get_minutes_seconds_from_time_str(time_string, is_minutes) {
	var tokens = time_string.split(":");
    
    var ret_str = tokens[0]
	if (!is_minutes) {
		ret_str = tokens[1]
	}
    
    return trim_preceeding_zeros(ret_str)
}

//Check if game was played in the before today minus 20 days (to allow time for video uploads)
function is_past_cur_date(date_str) {
    //Get current date
    var today_info = new Date()
    
    //Parse argument
    var date_yr = parseInt(trim_preceeding_zeros(date_str.substring(0, 4)), 10)
    var date_month = parseInt(trim_preceeding_zeros(date_str.substring(4, 6)), 10) - 1
    var date_day = parseInt(trim_preceeding_zeros(date_str.substring(6)), 10)
        
    //Add 20 days to agrument date
    date_day += 14
    if (date_day > 28) {
        date_day -= 28
        date_month += 1
        if (date_month > 11) {
            date_month = 0
            date_yr += 1
        }        
    }
        
    //Check to ensure date not in the future (or within 10 days of today)    
    if (date_yr > today_info.getFullYear()) { return true }
    if (date_yr == today_info.getFullYear()) {
        if (date_month > today_info.getMonth()) { return true }
        if (date_month == today_info.getMonth()) {
            if (date_day >= today_info.getDate()) { return true }
        }
    }
    
    return false
}

function is_static_uuid(uuid) {
    if (uuid in UUID_COUNT_LOOKUP) {
        if (UUID_COUNT_LOOKUP[uuid] >= MAX_ALLOWED_DUPS) {
            return true
        }
    }
    
    for each (var tmp_uuid in STATIC_VIDEO_UUID_BLACKLIST) {
        if (tmp_uuid == uuid) {
            return true
        }
    }
    
    return false
}

//Prints game info from a bit of the earliest and most recent set of games
function print_game_info_dict(game_info) {
    var cur_str = ""
    for (var i = 0; i < 30; ++i) {
        cur_str += ("{ 'year': \"" + game_info[i]['year'] + "\", 'id': \"" + game_info[i]['id'] + 
                        "\", 'htid': \"" + game_info[i]['htid'] +  "\", 'vtid': \"" + 
                        game_info[i]['vtid'] + "\" }, ")
    }
    print(cur_str)
    
    var glen = game_info.length - 3
    cur_str = ""
    for (var i = 0; i < 30; ++i) {
        cur_str += ("{ 'year': \"" + game_info[glen - i]['year'] + "\", 'id': \"" + game_info[glen - i]['id'] + 
                        "\", 'htid': \"" + game_info[glen - i]['htid'] +  "\", 'vtid': \"" + 
                        game_info[glen - i]['vtid'] + "\" },")
    }
    print(cur_str)    
}



//Script networking wrapper functions (with all assuming input validation already done)
function download_video_file(link_URL, directory) {
	feed = { output: '' }
	success = runCommand(UTILS_DIR + "get_clip.sh", link_URL, directory, feed)
	
	return !success
}

function get_json_obj(URL, use_socks) {
	feed = { output: '' }
    if (requires_socks() && use_socks) {
        success = runCommand(UTILS_DIR + "get_json.sh", URL, SOCKS_PORT_NUM, feed)            
    } else {        
        success = runCommand(UTILS_DIR + "get_json.sh", URL, feed)
    }
    
    var json_obj = null
    try {
        json_obj = JSON.parse(feed.output);
    } catch (err) {
        if (PRINT_JSON_ERRORS) { print(URL, err.toString()) }
    }
    
	return json_obj
}

function is_socks_down() {
    feed = { output: '' }
    success = runCommand(UTILS_DIR + "check_reverse_tunnel.sh", SOCKS_PORT_NUM, feed)
    
    return success
}

function get_xml_obj(URL) {
    //Use this as a safe check of URL
	try {
		video_XML_string = readUrl(URL)
	} catch(err) {
		return false
	}
    
    //Unforunately, readUrl does not return entire XML so need underlying script 
	feed = { output: '' }
	runCommand(UTILS_DIR + "get_xml.sh", URL, feed)

	return new XML(feed.output);
}


//NBA specific API calls for info
function get_all_game_info_dict() {
    //Get meta info from NBA calender JSON file
    var json_games_obj = get_json_obj("http://data.nba.net/10s/prod/v1/calendar.json", false)
    if (json_games_obj == null) { return null }
    
    var start_str = json_games_obj['startDate']
    var start_yr = start_str.substring(0, 4), start_month = start_str.substring(4, 6) 

    var end_str = json_games_obj['endDate']
    var end_yr = end_str.substring(0, 4), end_month = end_str.substring(4, 6)

    var cur_year = parseInt(start_yr, 10)
    var cur_month = parseInt(start_month, 10)
    var cur_day = parseInt(start_str.substring(6), 10)

    var last_yr = parseInt(end_yr, 10)
    var last_month = parseInt(end_month, 10)

    
    //Get all days with at least one game
    var game_days = []
    for (; cur_year <= last_yr; ++cur_year) {        
        for (; cur_month <= 12; ++cur_month) {
            if (cur_month > last_month && cur_year >= last_yr) {
                break             
            }
            
            for (; cur_day <= 31; ++cur_day) {
                cur_date = cur_day.toString()
                if (cur_date < 10) { cur_date = "0" + cur_date }
                
                cur_date = cur_month.toString() + cur_date
                if (cur_month < 10) { cur_date = "0" + cur_date }
                
                cur_date = cur_year.toString() + cur_date            
                if (cur_date in json_games_obj) {
                    if (parseInt(json_games_obj[cur_date]) > 0) {
                        game_days.push(cur_date)
                    }
                }
            }
            
            cur_day = 1
        }
        
        cur_month = 1;
    }


    //Get game ID's
    var games_id_info = []
    for each (var date_str in game_days) {
        var date_str = sanitize_input(date_str)
        
        if(!is_past_cur_date(date_str)) {            
            var cur_URL_str = GAMES_ON_DAY_TEMPLATE_URL.replace("DATE_STR", date_str)
            var json_scoreboard_obj = get_json_obj(cur_URL_str, false)
            
            if (json_scoreboard_obj != null) {
                var game_info = json_scoreboard_obj['games']
                
                for each (var game_row in game_info) {
                    games_id_info.push({ 'year': sanitize_input(game_row['seasonYear']), 
                                            'id': sanitize_input(game_row['gameId']),
                                            'htid': sanitize_input(game_row['hTeam']['teamId']),
                                            'vtid': sanitize_input(game_row['vTeam']['teamId']) })
                }
            }
        }
    }
        
        
    //Return dictionary with needed game info
    return games_id_info
}

function get_event_UUID(game_num, event_num) {
	var tmp_UUID_URL = EVENT_UUID_TEMPLATE_URL.replace("GAME_ID_VAL", game_num)
	tmp_UUID_URL = tmp_UUID_URL.replace("EVENT_ID_VAL", event_num)

    var json_uuid_obj = get_json_obj(tmp_UUID_URL, true)
    if (json_uuid_obj == null) { return false }

    if (json_uuid_obj.resultSets.Meta.videoUrls.length > 0) {
        return json_uuid_obj.resultSets.Meta.videoUrls[0].uuid
    } else {
        return false
    }
}

function get_player_jersey_num(player_id, team_id, season_str) {
    //Look up only if not yet found
	if (!(player_id in JERSEY_NUM_LOOKUP)) {
        var final_player_URL = PLAYER_INFO_TEMPLATE_URL.replace("TEAM_ID_VAL", team_id)
        final_player_URL = final_player_URL.replace("SEASON_STR", season_str)
        
        var json_team_obj = get_json_obj(final_player_URL, true)
        if (json_team_obj == null) { return MAGIC_ERROR_STR }
                        
        //Scan team's player ID's to find the desired player and get jersey number
        var num_players = json_team_obj.resultSets[0].rowSet.length                
        for (var player_i = 0; player_i < num_players; ++player_i) {
            var tmp_player_info = json_team_obj.resultSets[0].rowSet[player_i]
            if (tmp_player_info[PLAYER_ID_INDEX] == player_id) {
                JERSEY_NUM_LOOKUP[player_id] = parseInt(tmp_player_info[JERSEY_NUM_INDEX])
                break
            }

            //Return error if ID was not found
            if (player_i + 1 == num_players) {
                return MAGIC_ERROR_STR
            }
        }
	}
	
    //Return jersey number
	return JERSEY_NUM_LOOKUP[player_id]
}


//XML building related functionality
function output_XML_token(tag_name, token_val, num_indents) {
	var ret_string = ""
	
	for (j = 0; j < num_indents; ++j) {
		ret_string += "\t"
	}
	
	ret_string += "<" + tag_name + ">"
	ret_string += token_val
	ret_string += "</" + tag_name + ">\n"
	
	return ret_string
}

function output_label_tags(play_info, title_val, pid_key, team_ids, period) {    
	var ret_string = "\t<label>\n"
	
	//Do action title
	ret_string += output_XML_token("title", title_val, 2)
	
    
	//Do home vs. away
    var cur_team_str = [ "HOME", "AWAY" ]
    if (play_info[PBP_TEAM_ID_KEY] != team_ids[0]) {
        cur_team_str = [ "AWAY", "HOME" ]
    }
    
    var final_team_str = cur_team_str[0]
	if (pid_key != PBP_PLAYER_ID_KEY && pid_key != PBP_TEAMMATE_ID_KEY) {
        final_team_str = cur_team_str[1]
	}
    
    ret_string += output_XML_token("color", final_team_str, 2)
    
    
	//Do jersey number	
    var final_team_id = team_ids[0]
    if (final_team_str == "AWAY") {
        final_team_id = team_ids[1]
    }
    
    var season_str = team_ids[2]
    var added_str = parseInt(season_str) - 2000 + 1
    season_str += ("-" + added_str.toString())
    
	ret_string += output_XML_token("jersey", get_player_jersey_num(play_info[pid_key], 
                                                        final_team_id, season_str), 2)
	
    
	//Do time on the game clock
	ret_string += output_XML_token("quarter", (parseInt(period) + 1), 2)    
	ret_string += output_XML_token(
						"minutes", get_minutes_seconds_from_time_str(play_info['cl'], true), 2)
	ret_string += output_XML_token(
						"seconds", get_minutes_seconds_from_time_str(play_info['cl'], false), 2)
	
	//Return final string
	ret_string += "\t</label>\n"
	return ret_string
}

function get_event_XML_string(play_info, uuid_string, team_ids, period, prev_had_video) { 
	var skip_next = false
	var overwrite_prev = false
	var final_XML_string = "<event>\n"        
        
	//Get video links from XML file
	var video_XML_string = VID_UUID_XML_TEMPLATE_URL.replace("UUID_VAL", uuid_string)
	var video_XML_obj = get_xml_obj(video_XML_string)
	
	if (video_XML_obj) {
        var vid_URL = video_XML_obj.files.file.(@key=="turner_mp4_768x432_1500")[0]
        final_XML_string += output_XML_token("videoLink", vid_URL, 1)
        
        vid_URL = video_XML_obj.files.file.(@key=="turner_mp4_640x360_600")[0]
        final_XML_string += output_XML_token("videoLink", vid_URL, 1)
			
	} else {
		return [MAGIC_ERROR_STR, skip_next, overwrite_prev]
	}

    
	//Get action label information
	var event_id = parseInt(play_info['etype'])
	var event_detailed_id = parseInt(play_info['mtype'])
	var event_descript_string = play_info['de']
    
	//MAKE == 1
	if (event_id == 1) {
		if (event_descript_string.indexOf("3PT Jump Shot") == -1) {
			final_XML_string += output_label_tags(play_info, "2PT", PBP_PLAYER_ID_KEY, team_ids, period)
		} else {
			final_XML_string += output_label_tags(play_info, "3PT", PBP_PLAYER_ID_KEY, team_ids, period)
		}
		
		if (event_descript_string.indexOf("AST") != -1) {
			final_XML_string += output_label_tags(play_info, "ASSIST", PBP_TEAMMATE_ID_KEY, team_ids, period)     
		}
		
        //Offensive rebound leading to made tip
		if (event_detailed_id == 97 || event_detailed_id == 107) {
            final_XML_string += output_label_tags(play_info, "REBOUND", PBP_PLAYER_ID_KEY, team_ids, period)

            if (prev_had_video) {
                overwrite_prev = true
            }
		}
		
	//MISS == 2	
	} else if (event_id == 2) {
		final_XML_string += output_label_tags(play_info, "FGA", PBP_PLAYER_ID_KEY, team_ids, period)
		
        //Offensive rebound leading to missed tip
		if (event_detailed_id == 97 || event_detailed_id == 107) {
            final_XML_string += output_label_tags(play_info, "REBOUND", PBP_PLAYER_ID_KEY, team_ids, period)
            
            if (prev_had_video) {
                overwrite_prev = true
            }
		}
		
		if (play_info[PBP_OPP_PLAYER_ID_KEY] != "") {
			final_XML_string += output_label_tags(play_info, "BLOCK", PBP_OPP_PLAYER_ID_KEY, team_ids, period)
		}
		
	//FREE THROWS == 3 
	} else if (event_id == 3) {
		if (event_descript_string.toUpperCase().indexOf("MISS") != -1) {
			final_XML_string += output_label_tags(play_info, "FTMISS", PBP_PLAYER_ID_KEY, team_ids, period)
		} else {
			final_XML_string += output_label_tags(play_info, "FTMAKE", PBP_PLAYER_ID_KEY, team_ids, period)			
		}
        
	//REBOUND == 4
	} else if (event_id == 4) {
		final_XML_string += output_label_tags(play_info, "REBOUND", PBP_PLAYER_ID_KEY, team_ids, period)

	//TURNOVER == 5
	} else if (event_id == 5) {
		final_XML_string += output_label_tags(play_info, "TURNOVER", PBP_PLAYER_ID_KEY, team_ids, period)
		
		if (event_descript_string.indexOf("STEAL") != -1) {
			final_XML_string += output_label_tags(play_info, "STEAL", PBP_OPP_PLAYER_ID_KEY, team_ids, period)					
		}

	//FOUL == 6
	} else if (event_id == 6) {
        if (event_detailed_id != 14 && event_detailed_id != 17) {
            final_XML_string += output_label_tags(play_info, "FOUL", PBP_PLAYER_ID_KEY, team_ids, period)
            
            //Event_detailed_id == [4, 26] (offensive foul)
            if (event_detailed_id == 4 || event_detailed_id == 26) {
                final_XML_string += output_label_tags(play_info, "TURNOVER", PBP_PLAYER_ID_KEY, team_ids, period)			
                skip_next = true
            }
        
        //Flagrant or 3 second violation        
        } else {
            final_XML_string += output_label_tags(play_info, "FOULUNIQUE", PBP_PLAYER_ID_KEY, team_ids, period)			
        }
        
	//DEFENSIVE GOALTENDING == 7 AND FLAGARENT == 11 
	} else if (event_id == 7 || event_id == 11) {
		final_XML_string += output_label_tags(play_info, "FOULUNIQUE", PBP_PLAYER_ID_KEY, team_ids, period)
	
	//TIP == 10 (skip SUB == 8 AND TIMEOUT == 9)	
	} else if (event_id == 10) {        
        final_XML_string += output_label_tags(play_info, "TIP", PBP_PLAYER_ID_KEY, team_ids, period)
		
	// Not a usable event, so return false
	} else {
		return [MAGIC_ERROR_STR, skip_next, overwrite_prev]
	}
	
    
	//Finish XML and return string
	final_XML_string += "</event>"
	return [final_XML_string, skip_next, overwrite_prev]
}











////////////  Main Routine  ////////////


//Do set-up of look-up table
for (var i = 0; i <= MAX_ALLOWED_DUPS; ++i) {
    REPEATED_UUIDS_NUM_LOOKUP[i] = []
}

//Get JSON object with the all game information
games_id_info = get_all_game_info_dict()

if (games_id_info == null) {
    print("ERROR: Could not get basic info needed from NBA.com")
    quit()
}


//Get plays for each elapsed game  
while (games_id_info.length > 0) {
    //Set up variables
	var cur_index = Math.floor(Math.random() * games_id_info.length)
    
	var game_dict = games_id_info[cur_index]
    games_id_info.splice(cur_index, 1)
    
    var cur_season = game_dict['year']
    var cur_game_id = game_dict['id']
    var team_ids = [ game_dict['htid'], game_dict['vtid'], cur_season ]

    var cur_URL_str = PBP_TEMPLATE_URL.replace("SEASON_VAL", cur_season)
    cur_URL_str = cur_URL_str.replace("GAME_ID", cur_game_id)

    //Get JSON object for events if it exists
    var pbp_obj = get_json_obj(cur_URL_str, true)    
    if (pbp_obj != null) {            
        //Prepare filesystem for video/label
        var game_dir_string = BASE_DIR + DOWNLOADS_DIR + cur_game_id + "/"
        var game_dir = new File(game_dir_string)
        var game_done_file = new File(game_dir_string + DONE_FILE_NAME)
        
        //Check if game is complete 
        if (!(game_dir.isDirectory() && game_done_file.isFile())) {
            //Lock shared process lock		
            runCommand("lockfile", "/tmp/nba_pbp_lock.lock", { output: '' })
            
            //Check if any other thread is currently processing the same game already
            if (another_thread_taking_care_of_it(cur_game_id)) {
                runCommand("rm", "-f", "/tmp/nba_pbp_lock.lock", { output: '' })
                continue
            }
            
            //Create game directory and print progress
            print("Currently processing Game ID " + cur_game_id + ".... ")
            game_dir.mkdir()
            
            //Unlock shared process lock
            runCommand("rm", "-f", "/tmp/nba_pbp_lock.lock", { output: '' })
            
                
            //Get play-by-play info and each play's period as lists
            var pbp_list = []
            var period_list = []
            for (var per_i = 0; per_i < pbp_obj.g.pd.length; ++per_i) {
                var plays = pbp_obj.g.pd[per_i]['pla']
                for each (var play_info in plays) {
                    pbp_list.push(play_info)
                    period_list.push(per_i)
                }
            }
            
            //Get necessary info for the labels and accompanying video
            var skip_next = false     
            var overwrite_prev = false     
            var prev_had_video = false
            
            for (var play_i = 0; play_i < pbp_list.length; ++play_i) {
                var event_id = sanitize_input(pbp_list[play_i]['evt'])
                
                var event_dir_string = game_dir_string + event_id + "/"
                var event_dir = new File(event_dir_string)
                var event_done_file = new File(event_dir_string + DONE_FILE_NAME)
                
                //Print progress and check SOCKS if necessary
                if ((play_i % 50) == 0) { 
                    if (requires_socks() && is_socks_down()) {
                        print("ERROR: SOCKS proxy is no longer up, so download process will now terminate!")
                        quit()
                    }
                    
                    print("\tOn event #" + play_i + " (out of " + pbp_list.length + ")")
                }
                
                //Ensure that directory as not yet been covered
                if (!(event_dir.isDirectory() && event_done_file.isFile())) {
                    event_dir.mkdir()
                    
                    if (!skip_next) {
                        var uuid = get_event_UUID(cur_game_id, event_id)
                        if (uuid && !is_static_uuid(sanitize_input(uuid))) {
                            //Keep track of repeated UUID's bc they are an indication of static videos
                            uuid = sanitize_input(uuid)
                            
                            if (!(uuid in UUID_COUNT_LOOKUP)) {
                                UUID_COUNT_LOOKUP[uuid] = 1
                                REPEATED_UUIDS_NUM_LOOKUP[1].push(uuid)
                            } else {
                                var new_count = UUID_COUNT_LOOKUP[uuid] + 1
                                
                                if (new_count <= MAX_ALLOWED_DUPS) {
                                    UUID_COUNT_LOOKUP[uuid] = new_count
                                    REPEATED_UUIDS_NUM_LOOKUP[new_count].push(uuid)
                                }
                            }
                            
							//Get XML string
							var final_string_set = get_event_XML_string(pbp_list[play_i], uuid, 
                                                                            team_ids, 
                                                                            period_list[play_i], 
                                                                            prev_had_video)
                            			
                            var final_string = final_string_set[0]
                            skip_next = final_string_set[1]
                            overwrite_prev = final_string_set[2]
                            
                            //If usable event, attempt to save XML file and associated videos
                            if (final_string.indexOf(MAGIC_ERROR_STR) == -1) {				                                
                                //Get video files
                                var successful = true
                                var tmp_XML_obj = new XML(final_string)
                                
                                for each(var video_link in tmp_XML_obj.videoLink) { 
                                    successful = download_video_file(video_link, event_dir_string)
                                    if (!successful) { break }
                                }

                                //Print to file	(e.g. cur_game_id/event_i/label.xml)
                                if (successful) {
                                    var final_XML_filename = event_dir_string + "event.xml"
                                    if (overwrite_prev && play_i > 0) {
                                        final_XML_filename = (game_dir_string + 
                                                                sanitize_input(pbp_list[play_i-1]['evt']) + 
                                                                "/event.xml")
                                    }
                                    
                                    var event_XML_file = new FileWriter(final_XML_filename)
                                    event_XML_file.write(final_string)
                                    event_XML_file.flush()
                                    event_XML_file.close()
                                }
                                
                                prev_had_video = successful
                                
                            } else {
                                prev_had_video = false
                            }
                        }
                        
                    } else {
                        skip_next = false
                    }
                    
                    //Mark event done and do garbage collection to avoid accumulation too many open Files
                    event_done_file.createNewFile()
                    gc()
                }
            }
            
            //Mark game as done
            game_done_file.createNewFile()
            print("")
        }
    }
}


//Print highly repeated UUID's
if (PRINT_BAD_UUIDS) {
    print("Newly identified static UUID's:  \n")
    for each (var uuid in REPEATED_UUIDS_NUM_LOOKUP[MAX_ALLOWED_DUPS]) {
        print(uuid)
    }
}


//Print completion message
print("\n\nSCRIPT COMPLETE!!!")
quit()
