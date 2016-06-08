#!/usr/bin/env bash

### CONFIGURATION ###
DL_PATH=$HOME/Downloads # Default: $HOME/Downloads
TEMP_PATH=/tmp/animefreak_dl # Default: /tmp/animefreak_dl
### END CONFIGURATION ###

USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:48.0) Gecko/20100101 Firefox/48.0"
BASE_URL="http://www.animefreak.tv"
SEARCH=$@

# Redirect errors to log file
mkdir -p $TEMP_PATH
exec 2> $TEMP_PATH/log.txt

###################### MIRRORS #########################
# Accepts 1 arg: html response from the server ($RESPONSE)
ANIMEFREAK() {
echo "$1" | grep -Po "http.*anime1.*st=.{22}&e=.{10}"
# URL_DEC "$1"\
# 	| grep "movie"\
# 	| egrep -o -e "=http..*st=.{22}" -e "=http..*e=.{10}"\
# 	| sed 's/=//'
}

UPLOAD2() {
echo "$1"\
	| grep -o "video=http.*"\
	| sed 's/\&rating/\n/'\
	| grep -o -m 1 "http.*"
}

MP4UPLOAD() {
# echo "$1" | grep "file" | grep -o "http.*mp4'"
echo "$1" | grep "file" | grep -o "http.*mp4" | sed -n 1p 
}

VIDEOBAM() {
echo "$1"\
	| grep "var player_config"\
	| sed -e 's/[\]//g' -e 's/[",]/ /g'\
	| grep -o "http.*"\
	| awk {'print $12'}
}

VIDEOWEED() {
HOST="http://www.videoweed.es/api/player.api.php?"
KEY=$(echo "$1"\
	| grep -o "fkz=.*-"\
	| sed -e 's/fkz="//' -e 's/-$//')
FILE=$(echo "$1"\
	| grep -o 'file=.*"'\
	| sed -e 's/file="//' -e 's/"//g')
RESPONSE_2=""$HOST"file="$FILE"&key="$KEY""
RESPONSE_2=$(GET "$RESPONSE_2" -)
echo "$RESPONSE_2" | sed -e 's/url=//' -e 's/.flv.*$/.flv?client=FLASH/'
}

NOVAMOV() {
HOST="http://www.novamov.com/api/player.api.php?"
KEY=$(echo "$1"\
	| grep -o "filekey=.*-"\
	| sed -e 's/filekey="//' -e 's/-$//')
FILE=$(echo "$1"\
	| grep -o "file=.*"\
	| sed -e 's/file="//' -e 's/";//')
RESPONSE_2=""$HOST"file="$FILE"&key="$KEY""
RESPONSE_2=$(URL_DEC "$(GET "$RESPONSE_2" -)")
echo "$RESPONSE_2" | sed -e 's/url=//' -e 's/.flv.*$/.flv?client=FLASH/'
}

SAFEUPLOAD() {
SUBS=$(echo "$1" | grep -o "http.*safeupload.org.*subtitles.*.vtt")
GET "$SUBS" "$TEMP_PATH/subs.srt"
echo "$1" | grep -o "https.*googleusercontent.*=m.."
}

################## INPUT CHECKS ####################
# Accepts 1 or 2 args for input checking
QUIT() {
if [ $1 == q ]; then
	echo "exit"
	exit
fi
}

BACK() {
if [ $1 == b ]; then
	break
fi
}

IS_NEXT() {
if [ $1 == n ]; then
	PAGE_COUNT=$(expr $PAGE_COUNT + 1)
	break
fi
}

IS_PREV() {
if [ $1 == p ]; then
	PAGE_COUNT=$(expr $PAGE_COUNT - 1)
	if [ $PAGE_COUNT -lt 0 ]; then
		PAGE_COUNT=0
		continue
	else
		break
	fi
fi
}

IS_NUM() {
if ! [[ $1 =~ ^[0-9]+$ ]]; then
	echo "Not a valid number or option"
	sleep 1
	continue
fi
}

IS_GREATER() {
if [ $1 -gt $2 ]; then
	echo "Not a valid number or option"
	sleep 1
	continue
fi
}

IS_ZERO() {
if [ $1 -eq 0 ]; then
	echo "Can not be 0"
	sleep 1
	continue
fi
}

NA() {
echo "Not a valid option"
sleep 1
continue
}

SEARCH_BR() {
if [ "$1" == s ]; then
	read -p "Search for? >> " SEARCH 2>&1
	break
fi
}

SEARCH_CONT() {
if [ "$1" == s ]; then
	read -p "Search for? >> " SEARCH 2>&1
	continue
fi
}

IS_RANGE() {
if [ $1 == r ]; then
	RANGE "$2"
	continue
fi
}

IS_ALL() {
if [ "$1" == a ]; then
	BATCH "$2" "$3" "$4"
	continue
fi
}

###################### SECONDARY FUNCTIONS #########################
GET() {
# Accepts 2 args: url or stdin and file or stdout
if [ "$1" == "-" ]; then
	wget -nv --referer="$BASE_URL" -U "$USER_AGENT" -i "$1" -O "$2"
else
	wget -nv --referer="$BASE_URL" -U "$USER_AGENT" "$1" -O "$2"
fi
}

MIRROR_SCRAPER() {
# Accepts 1 arg: html page of episode ($PAGE)
# "Fst" matches: anime1.com, raw ips, animefreak.old, animefreak.new
PASS_1=$(echo "$1"\
	| grep -e "Fst"\
		   -e "mp4upload"\
		   -e "upload2"\
		   -e "videobam"\
		   -e "novamov"\
		   -e "videoweed"\
		   -e "safeupload")
PASS_1=$(URL_DEC "$PASS_1")
# The order in which the mirrors appear is been decided here
M1=$(echo "$PASS_1" | egrep -o "http.*st=.{22}&e=.{10}") # matches anime1.com, raw ips
M2=$(echo "$PASS_1" | egrep -o "http.*freak.*e=h&st=h") # matches animefreak.new
M3=$(echo "$PASS_1" | egrep -o "http://www.mp4up.*\.html")
M4=$(echo "$PASS_1" | egrep -o "http.*safeupload.org/getembed/.{32}")
M5=$(echo "$PASS_1" | egrep -o "http.*upload2.*embed/.{10}")
M6=$(echo "$PASS_1" | egrep -o "http://videobam..*")
M7=$(echo "$PASS_1" | egrep -o "http://embed.videow.*v=.{13}" | sed 's/"//g')
M8=$(echo "$PASS_1" | egrep -o "http://embed.nova.*v=.{13}")
M9=$(echo "$PASS_1" | egrep -o "http.*freak.*e=.{10}&st=.{22}") # matches animefreak.old
echo -e "$M1\n$M2\n$M3\n$M4\n$M5\n$M6\n$M7\n$M8\n$M9" | awk ' !x[$0]++' | sed '/^$/d'
}

MIRROR_FILTER() {
# Choose the appropriate path according to the mirror selected
# Accepts 1 arg: mirror ($MIRROR) selected
TYPE=$(echo "$1"\
	| grep -o -e "animefreak.tv"\
			  -e "upload2"\
			  -e "mp4upload"\
			  -e "videobam"\
			  -e "videoweed"\
			  -e "novamov"\
			  -e "safeupload")
if [ "$TYPE" == "" ]; then
	echo "$1"
else
	RESPONSE=$(GET "$1" -)
	# echo "$RESPONSE" > $TEMP_PATH/response.htm
	if [ "$TYPE" == "animefreak.tv" ]; then
		ANIMEFREAK "$RESPONSE"
	elif [ "$TYPE" == upload2 ]; then
		UPLOAD2 "$RESPONSE"
	elif [ "$TYPE" == mp4upload ]; then
		MP4UPLOAD "$RESPONSE"
	elif [ "$TYPE" == videobam ]; then
		VIDEOBAM "$RESPONSE"
	elif [ "$TYPE" == videoweed ]; then
		VIDEOWEED "$RESPONSE"
	elif [ "$TYPE" == novamov ]; then
		NOVAMOV "$RESPONSE"
	elif [ "$TYPE" == safeupload ]; then
		SAFEUPLOAD "$RESPONSE"
	fi
fi
}

DOWNLOADER() {
# Accepts 3 args: the url ($URL), download path ($FILE_PATH)
# and the filename ($FILENAME)
echo
mkdir -p "$2"
wget -U "$USER_AGENT" --referer="$BASE_URL" "$1" -O "$2/$3" 2>&1
}

PLAYER() {
# Accepts 2 arg: the url ($URL) to be played and subtitles $SUBTITLES if any
if [ "$2" ]; then
	mpv -really-quiet -user-agent "$USER_AGENT" -sub-file "$2" "$1"
else
	mpv -really-quiet -user-agent "$USER_AGENT" "$1"
fi
}

URL_DEC() {
# URL decoder
local d=${1//+/ }; printf '%b' "${d//%/\\x}";
}

MORE_50() {
# Accepts 1 argument (trackers page number)
	MORE="$BASE_URL/views/ajax?js=1&page=$1&view_name=tracker&view_display_id=page&view_path=tracker&view_base_path=tracker&view_dom_id=1&pager_element=0&view_args="
	GET $MORE -
}

HELP() {
echo "\
Interactive script for viewing or downloading videos from Animefreak.tv.

Calling the script without arguments will list the latest uploaded
videos. Append a search term after the command to \"grep\" the
entire catalog of Animefreak. For example:

./animefreak-downloader.sh monogatari

Wget needs to be intalled for downloading. mpv (optional) for
viewing videos.

Options:	-h 	     print this help tip"
}

###################### MAIN FUNCTIONS #########################
CATALOG_1() {
# Accepts 1 arg: list of all the series ($CATALOG)
while :
do
	clear
	RESULTS=$(echo "$1" | grep -i "\".*$SEARCH")
	LINKS=$(echo "$RESULTS"\
		| grep -o '^.*"'\
		| sed -e "s#^#$BASE_URL#" -e 's/"//')
	TITLES=$(echo "$RESULTS"\
		| grep -o '".*$' | sed 's/"//'\
		| sed 's/\\x26/\&/g'\
		| sed "s/&#039;/'/g"\
		| sed 's/&amp;/\&/g')
	R_COUNT=$(echo "$RESULTS" | wc -l)
	if [ -z "$RESULTS" ]; then
		read -p "No title found containing the word(s) $SEARCH. Search for? >> " SEARCH 2>&1
		continue
	fi
	echo "$TITLES" | awk '{print NR, $0}' | column
	read -p "Found $R_COUNT results containing the word(s): $SEARCH. Type a number to select a series and press enter. (s) to search again. (q) to quit. >> " EP 2>&1
	QUIT $EP
	SEARCH_CONT $EP
	IS_NUM $EP
	IS_GREATER $EP $R_COUNT
	IS_ZERO $EP
	EP_PAGE=$(echo "$LINKS" | sed -n "$EP"p | GET - -)
	EP_LINKS=$(echo "$EP_PAGE"\
		| grep -i "leaf"\
		| grep -o '/wa.*"'\
		| sed -e "s#^#$BASE_URL#" -e 's/"$//'\
		| awk ' !x[$0]++')
	EP_TITLES=$(echo "$EP_PAGE"\
		| grep -i "leaf"\
		| grep -o 'wa.*</a'\
		| grep -o '>.*<'\
		| sed 's/[<,>]//g'\
		| sed "s/&#039;/'/g"\
		| sed 's/&amp;/\&/g'\
		| awk ' !x[$0]++')
	if [ -z "$EP_LINKS" ]; then
		PAGE="$EP_PAGE"
		PAGE_SCRAPER "$PAGE"
	else
		break
	fi
done
}

CATALOG_2() {
# Accepts 2 args: list of episode links ($EP_LINKS)
# and titles ($EP_TITLES)
while :
do
	clear
	R_COUNT=$(echo "$1" | wc -l)
	echo "$2" | awk '{print NR, $0}' | more 2>&1
	read -p "Select an episode, (a) to download all, (r) to download range, (s) to make a new search, (q) to quit. >> " EP 2>&1
	SEARCH_BR "$EP"
	IS_ALL "$EP" 1 "$R_COUNT" "$1"
	IS_RANGE $EP "$1"
	QUIT $EP
	IS_NUM $EP
	IS_GREATER $EP $R_COUNT
	IS_ZERO $EP
	PAGE=$(echo "$1" | sed -n "$EP"p | GET - -)
	PAGE_SCRAPER "$PAGE"
done
}

LATEST() {
# Accepts 2 args: list of episode links ($EP_LINKS)
# and titles ($EP_TITLES)
while :
do
	clear
	R_COUNT=$(echo "$1" | wc -l)
	echo "$2" | awk '{print NR, $0}' | more 2>&1
	read -p "Select an episode (1-50), (r) to download range, (n/p) next/previous 50 episodes, (q) to quit. >> " EP 2>&1
	IS_NEXT $EP
	IS_PREV $EP
	IS_RANGE $EP "$1"
	QUIT $EP
	IS_NUM $EP
	IS_GREATER $EP $R_COUNT
	IS_ZERO $EP
	PAGE=$(echo "$1" | sed -n "$EP"p | GET - -)
	PAGE_SCRAPER "$PAGE"
done
}

PAGE_SCRAPER() {
# Accepts 1 arg: the html page ($PAGE) containing the videos
while :
do
	MIRRORS=$(MIRROR_SCRAPER "$1")
	echo "$MIRRORS" >> $TEMP_PATH/log.txt
	if [ -z "$MIRRORS" ]; then
		echo "Can't detect a working mirror. Press enter to go back..."
		read 2>&1
		break
	fi
	TITLE=$(echo "$1"\
		| grep -o " / .*</p"\
		| sed -e 's/ \/ //' -e 's/<\/p//'\
		| sed "s/&#039;/'/g"\
		| sed 's/&amp;/\&/g')
	DIR=$(echo "$TITLE" | sed -e 's/ Episode.*$//' -e 's#[<>:"/\|?*]#_#g')
	FILENAME=$(echo "$TITLE" | sed -e 's/ Episode /.ep/'\
								   -e 's/$/.mp4/'\
							 	   -e 's#[<>:"/\|?*]#_#g')
	SUB_FILENAME=$(echo "$TITLE" | sed -e 's/ Episode /.ep/'\
									   -e 's/$/.srt/'\
								 	   -e 's#[<>:"/\|?*]#_#g')
	M_COUNT=$(echo "$MIRRORS" | wc -l)
	if [ "$M_COUNT" -eq 1 ]; then
		MIRROR=$MIRRORS
	else
		clear
		echo "$MIRRORS"\
			| grep -o -e "http://[0-9].*[0-9]/"\
					  -e "animefreak.tv"\
					  -e "upload2.com"\
					  -e "mp4upload.com"\
					  -e "videobam.com"\
					  -e "novamov.com"\
					  -e "videoweed.es"\
					  -e "anime1.com"\
					  -e "safeupload.org"\
			| sed -e 's/safeupload.org/safeupload.org <--- Usually in 360p 720p 1080p and external subtitles./'\
				  -e 's/novamov.com/novamov.com <--- NOT WORKING/'\
				  -e 's/videoweed.es/videoweed.es <--- NOT WORKING/'\
			| awk '{print NR, $0}'
		read -p "There are $M_COUNT mirrors for $TITLE Select a number and press enter, (b) to go back, (q) to quit. >> " M_NUM 2>&1
		QUIT $M_NUM
		BACK $M_NUM
		IS_NUM $M_NUM
		IS_ZERO $M_NUM
		IS_GREATER $M_NUM $M_COUNT
		MIRROR=$(echo "$MIRRORS" | sed -n "$M_NUM"p)
	fi
	URL=$(MIRROR_FILTER "$MIRROR")
	IS_SAFEUPLOAD=$(echo "$MIRROR" | grep -o safeupload) 
	if [ "$IS_SAFEUPLOAD" == safeupload ]; then
		SUBTITLES="$TEMP_PATH/subs.srt" 
		M_COUNT=$(echo "$URL" | wc -l)
		while :
		do
			echo "$URL" | sed -e 's/.*m18$/360p/'\
						 	  -e 's/.*m22$/720p/'\
							  -e 's/.*m37$/1080/'\
						| awk '{print NR, $0}'
			read -p "Choose a resolution. Subtitles automatically will be downloaded." QUAL 2>&1
			if [ $QUAL -le $M_COUNT -a $QUAL -gt 0 ]; then
				URL=$(echo "$URL" | sed -n "$QUAL"p)
				break
			else
				continue
			fi
		done
	else
		SUBTITLES="" 
	fi
	FILE_PATH="$DL_PATH/$DIR"
	FULL_PATH="$FILE_PATH/$FILENAME"
	while :
	do
		ERROR=CONT
		read -p "View (v) or save (s) video? (b) to go back (q) to quit. >> " CHOICE 2>&1
		if [ -f "$FULL_PATH" -a $CHOICE == s ]; then
			read -p "$FILENAME already exists. Press (y) to overwrite or enter to go back. >> " CHOICE_2 2>&1
			if [ "$CHOICE_2" != y ]; then
				break
			fi
		fi
		QUIT $CHOICE
		BACK $CHOICE
		if [ "$CHOICE" == s ]; then
			if [ "$IS_SAFEUPLOAD" == safeupload ]; then
				mkdir -p "$FILE_PATH"
				mv "$SUBTITLES" "$FILE_PATH/$SUB_FILENAME"
			fi
			DOWNLOADER "$URL" "$FILE_PATH" "$FILENAME"
			if [ $? != 0 ];then
				ERROR=TRUE
			else
				ERROR=FALSE
			fi
			break
		elif [ "$CHOICE" == v ]; then
			PLAYER "$URL" "$SUBTITLES"
			if [ $? != 0 ];then
				ERROR=TRUE
			else
				ERROR=NA
			fi
			break
		else
			NA
		fi
	done
	if [ $ERROR == "TRUE" ]; then
		read -p "Seems there was an error, try a different mirror? (y) for yes, enter to continue. >> " DIFF 2>&1
		if [ "$DIFF" == y ]; then
			continue
		else
			break
		fi
	elif [ $ERROR == "CONT" ]; then
		break
	elif [ $ERROR == "NA" ]; then
		continue
	elif [ $ERROR == "FALSE" ]; then
		echo -ne $'\a'
		read -p "Done! Press enter to continue." 2>&1
		break
	fi
done
}

RANGE() {
# Accepts 1 arg: a list of links ($EP_LINKS) where the range will
# act upon
while :
do
	echo "Type (b) in either field to go back."
	read -p "Download from:" START 2>&1
	BACK $START
	IS_NUM $START
	IS_GREATER $START $R_COUNT
	IS_ZERO $START
	read -p "To:" END 2>&1
	BACK $END
	IS_NUM $END
	IS_GREATER $START $END
	IS_ZERO $END
	BATCH $START $END "$1"
	break
done
}

BATCH() {
# Accepts 3 args: start and end point ($START) ($END),
# and a list of episode links ($EP_LINKS)
while [ $1 -le $2 ]
do
	PAGE=$(echo "$3" | sed -n "$1"p | GET - -)
	MIRRORS=$(MIRROR_SCRAPER "$PAGE")
	echo "$MIRRORS" >> $TEMP_PATH/log.txt
	if [ -z "$MIRRORS" ]; then
		echo -ne $'\a'
		read -p "Can't detect a working mirror. Press enter to continue to the next episode or (c) to cancel. >> " CHOICE 2>&1
		if [ "$CHOICE" == c ]; then
			break
		else
			set -- "$(expr $1 + 1)" "${@:2:3}"
			continue
		fi
	fi
	M_COUNT=$(echo "$MIRRORS" | wc -l)
	M_NUM=1
	while [ $M_NUM -le $M_COUNT ]
	do
		MIRROR=$(echo "$MIRRORS" | sed -n "$M_NUM"p)
		TITLE=$(echo "$PAGE"\
			| grep -o " / .*</p"\
			| sed -e 's/ \/ //' -e 's/<\/p//'\
			| sed "s/&#039;/'/g"\
			| sed 's/&amp;/\&/g')
		DIR=$(echo "$TITLE" | sed -e 's/ Episode.*$//' -e 's#[<>:"/\|?*]#_#g')
		URL=$(MIRROR_FILTER "$MIRROR")
		FILE_PATH="$DL_PATH/$DIR"
		FILENAME=$(echo "$TITLE" | sed -e 's/ Episode /.ep/'\
									   -e 's/$/.mp4/'\
									   -e 's#[<>:"/\|?*]#_#g')
		SUB_FILENAME=$(echo "$TITLE" | sed -e 's/ Episode /.ep/'\
										   -e 's/$/.srt/'\
										   -e 's#[<>:"/\|?*]#_#g')
		IS_SAFEUPLOAD=$(echo "$MIRROR" | grep -o safeupload) 
		if [ "$IS_SAFEUPLOAD" == safeupload ]; then
			SUBTITLES="$TEMP_PATH/subs.srt" 
			URL=$(echo "$URL" | tail -n 1)
			mkdir -p "$FILE_PATH"
			mv "$SUBTITLES" "$FILE_PATH/$SUB_FILENAME"
		fi
		# FULL_PATH="$FILE_PATH/$FILENAME"
		# if [ -f $FULL_PATH -a $CHOICE == s ]; then
		# 	echo -ne $'\a'
		# 	read -p "$FILENAME already exists. Press (y) to overwrite or enter to continue to the next episode. >> " CHOICE_2 2>&1
		# 	if [ "$CHOICE_2" != y ]; then
		# 		set -- "$(expr $1 + 1)" "${@:2:3}"
		# 		break
		# 	fi
		# fi
		DOWNLOADER "$URL" "$FILE_PATH" "$FILENAME"
		if [ $? != 0 ];then
			M_NUM=$(expr $M_NUM + 1)
			echo "Seems there was an error, trying a different mirror"
			continue
		else
			set -- "$(expr $1 + 1)" "${@:2:3}"
			break
		fi
	done
	# echo -ne $'\a'
	# read -p "Can't detect a working mirror. Press enter to continue to the next episode or (c) to cancel. >> " CHOICE 2>&1
	# if [ "$CHOICE" == c ]; then
	# 	break
	# else
	# 	set -- "$(expr $1 + 1)" "${@:2:3}"
	# 	continue
	# fi
done
echo -ne $'\a'
read -p "Done! Press enter to continue." 2>&1
}


if [ "$1" == -h ]; then
	HELP
	exit
elif [ "$SEARCH" ]; then
	echo "Getting anime catalog"
	BOOK=$(GET "$BASE_URL/book" -)
	CATALOG=$(echo "$BOOK"\
		| grep -o '"/w.*</a'\
		| sed -e 's/"//' -e 's/<\/a//' -e 's/">/"/')
	while :
	do
		CATALOG_1 "$CATALOG"
		CATALOG_2 "$EP_LINKS" "$EP_TITLES"
	done
else
	echo "Getting latest episodes."
	PAGE_COUNT=0
	while :
	do
		TRACKER=$(MORE_50 $PAGE_COUNT)
		EP_LINKS=$(echo $TRACKER\
			| sed 's/href/\nhref/g'\
			| grep -o "watch.*\\x3c/a"\
			| sed -e 's#\\"\\x3e#\t#' -e 's#\\x3c/a##'\
			| grep -Po "^.*\t" | sed "s#^#$BASE_URL/#")
		EP_TITLES=$(echo $TRACKER\
			| sed 's/href/\nhref/g'\
			| grep -o "watch.*\\x3c/a"\
			| sed -e 's#\\"\\x3e#\t#' -e 's#\\x3c/a##'\
			| grep -Po "\t.*$" | sed 's/\t//'\
			| sed 's/\\x26/\&/g'\
			| sed "s/&#039;/'/g"\
			| sed 's/&amp;/\&/g')
		LATEST "$EP_LINKS" "$EP_TITLES"
	done
fi
