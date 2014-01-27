#!/bin/bash

### CONFIGURATION ###
DOWNLOAD_PATH=$HOME/Downloads # Default: $HOME/Downloads
TEMP_PATH=/tmp/animefreak_downloader # Default: /tmp/animefreak_downloader
USER_AGENT="Mozilla/5.0 (X11; Linux i686; rv:25.0) Gecko/20100101 Firefox/25.0"
### END CONFIGURATION ###

SEARCH=$@

# Change directory
cd $TEMP_PATH 2>/dev/null || mkdir -p $TEMP_PATH && cd $TEMP_PATH

# Redirect errors to log file
exec 2>log.txt

PAGE_SCRAPER() {
# Get episode title, directory name, file name
TITLE=$(echo "$PAGE" | grep -m 1 title | grep -o "Watch.*|" | sed -e 's/Watch //' -e 's/Online |//')
DIR=$(echo "$PAGE" | grep -m 1 title | grep -o "Watch.*|" | sed -e 's/Watch //' -e 's/ Episode .*|//' -e 's/^ *//')
FILENAME=$(echo "$PAGE" | grep -m 1 title | grep -o "Watch.*|" | sed -e 's/Watch //' -e 's/ Online |//' -e 's/ Episode /.ep/' -e 's/$/.mp4/' -e 's/^ *//')

# Mirror detection
PASS_1=$(echo "$PAGE" | grep -e stream.php -e Fst -e upload2 -e mp4upload -e videobam -e videoweed -e novamov)
URL_DEC "$PASS_1" | grep -o "http.*animefreak.tv.*&st=......................" > mirrors.txt # animefreak
URL_DEC "$PASS_1" | grep -o '"http.*upload2.*embed/.*$' | sed -e 's/"//g' -e 's/><\/iframe.*$//' >> mirrors.txt # upload2.com
URL_DEC "$PASS_1" | grep -o "http://www.mp4upload.*\.html" >> mirrors.txt # mp4upload.com
URL_DEC "$PASS_1" | grep -o "http.*?st=.*&e=.........." >> mirrors.txt # direct
URL_DEC "$PASS_1" | grep -o "http://videobam..*" | sed 's/"/ /g' | awk {'print $1'} >> mirrors.txt # videobam
URL_DEC "$PASS_1" | grep -o "http://.*videoweed.*&width" | sed 's/&width//' >> mirrors.txt # videoweed
URL_DEC "$PASS_1" | grep -o "http://embed.novamov.com.*&v=.*&px" | sed 's/&px$//' >> mirrors.txt # novamov

# Sort mirrors, remove duplicates and empty lines
MIRRORS=$(uniq mirrors.txt | sed '/^$/d')

# Count number of mirrors
M_COUNT=$(echo "$MIRRORS" | wc  | awk {'print $1'})

# log
echo "INFO: Number of mirrors detected $M_COUNT which are: " >> log.txt
echo "$MIRRORS" >> log.txt
}

MIRROR_CHECK() {
# No mirrors found
if [ -z "$MIRRORS" ]
then
	read -p "Can't detect a working mirror :(. Press enter to go back..." 2>&1
	continue
fi
}

M_FILTER() {
# Choose the appropriate path according to the mirror selected
TYPE=$(echo "$MIRRORS" | sed -n "$M_NUM"p | grep -o -e animefreak.tv -e upload2 -e mp4upload -e videobam -e videoweed -e novamov)
if [ "$TYPE" == "animefreak.tv" ]
then
	DOWNLINK=$(wget -nv -U "$USER_AGENT" "$(echo "$MIRRORS" | sed -n "$M_NUM"p)" -O - | grep movie)
	URL=$(URL_DEC "$DOWNLINK" | grep -o -e "=http..*st=......................" -e "=http..*e=.........." | sed 's/=//')
elif [ "$TYPE" == upload2 ]
then
	DOWNLINK=$(wget -nv -U "$USER_AGENT" "$(echo "$MIRRORS" | sed -n "$M_NUM"p)" -O - | grep movie)
	URL=$(echo "$DOWNLINK" | grep -o "video=http..*" | sed 's/rating=/\n/' | sed -n 1p | sed -e 's/video=//' -e 's/&$//')
elif [ "$TYPE" == mp4upload ]
then
	DOWNLINK=$(wget -nv -U "$USER_AGENT" "$(echo "$MIRRORS" | sed -n "$M_NUM"p)" -O - | grep "eval" | sed 's/|/\n/g' | grep -A3 -e IFRAME -e video | \
	sed -n -e 4p -e 7p)
	URL=$(echo "http://"$(echo "$DOWNLINK" | sed -n 1p)".mp4upload.com:182/d/"$(echo "$DOWNLINK" | sed -n 2p)"/video.mp4?")
elif [ "$TYPE" == videobam ]
then
	DOWNLINK=$(wget -nv -U "$USER_AGENT" "$(echo "$MIRRORS" | sed -n "$M_NUM"p)" -O - | grep "var player_config")
	URL=$(echo "$DOWNLINK" | sed -e 's/[\]//g' -e 's/[",]/ /g' | grep -o "http.*" | awk {'print $12'})
elif [ "$TYPE" == videoweed ]
then
	VW=$(wget -nv -U "$USER_AGENT" "$(echo "$MIRRORS" | sed -n "$M_NUM"p)" -O -)
	KEY=$(echo "$VW" | grep -o "fkz=.*-" | sed -e 's/fkz="//' -e 's/-$//')
	FILE=$(echo "$VW" | grep -o "file=.*" | sed -e 's/file="//' -e 's/";//')
	DOWNLINK="http://www.videoweed.es/api/player.api.php?file="$FILE"&key="$KEY"&user=undefined&numOfErrors=0&cid3=embed.videoweed.es&pass=undefined&cid2=undefined&cid=0"
	URL=$(wget -nv -U "$USER_AGENT" "$DOWNLINK" -O - | sed -e 's/url=//' -e 's/.flv.*$/.flv?client=FLASH/')
elif [ "$TYPE" == novamov ]
then
	NOVAM=$(wget -nv -U "$USER_AGENT" "$(echo "$MIRRORS" | sed -n "$M_NUM"p)" -O -)
	KEY=$(echo "$NOVAM" | grep -o "filekey=.*-" | sed -e 's/filekey="//' -e 's/-$//')
	FILE=$(echo "$NOVAM" | grep -o "file=.*" | sed -e 's/file="//' -e 's/";//')
	DOWNLINK="http://www.novamov.com/api/player.api.php?file="$FILE"&cid2=undefined&cid=undefined&user=undefined&pass=undefined&key="$KEY"&numOfErrors=0"
	URL=$(URL_DEC "$(wget -nv -U "$USER_AGENT" "$DOWNLINK" -O -)" | sed -e 's/url=//' -e 's/.flv.*$/.flv?client=FLASH/')
else
	TYPE=direct
	URL=$(echo "$MIRRORS" | sed -n "$M_NUM"p)
fi
echo "INFO: $TYPE path chosen with url $URL" >> log.txt # log
}

BATCH() {
read -p "Start downloading multiple episodes? Press enter to continue, (b) to go back. >> " CHOICE 2>&1
if [ "$CHOICE" == b ]
then
	continue
else
	while [ "$EP" -le $R_COUNT ]
	do
		# Get page
		PAGE=$(echo "$CONTENT" | sed -n "$EP"p | sed 's/ .*$//' | wget -nv -U "$USER_AGENT" -i - -O -)
		PAGE_SCRAPER
		# Check if no mirrors
		if [ -z "$MIRRORS" ]
		then
			read -p "Can't detect a working mirror :(. Press enter to continue to the next episode or (c) to cancel. >> " CHOICE 2>&1
			if [ "$CHOICE" == c ]
			then
				break
			else
				EP=$(expr $EP + 1)
				continue
			fi
		fi
		M_NUM=1
		M_FILTER
		DOWNLOADER
		EP=$(expr $EP + 1)
	done
	read -p "Done! Press enter to continue." 2>&1
fi
}

DOWNLOADER() {
echo
mkdir -p "$DOWNLOAD_PATH/$DIR"
wget -U "$USER_AGENT" "$URL" -O "$DOWNLOAD_PATH/$DIR/$FILENAME" 2>&1
}

URL_DEC() {
local d=${1//+/ }; printf '%b' "${d//%/\x}";
}

INPUT_CHECK() {
if [ "$EP" == q ] # Quit
then
	echo "exit"
	exit
elif [ $EP == s ] # Search again
	then
	read -p "Search for? >> " SEARCH 2>&1
	continue
elif ! [[ "$EP" =~ ^[0-9]+$ ]] # Check if it is a number
then
	echo "Not a valid number or option"
	sleep 1
	continue
elif [ "$EP" -gt "$R_COUNT" -o "$EP" -eq 0 ] # Check if 0 or greater than $R_COUNT
then
	echo "Not a valid number or option"
	sleep 1
	continue
fi
}

HELP() {
echo "Interactive script for viewing or downloading videos from Animefreak.tv.

Downloading of single episodes, range of episodes or entire series is possible.

Calling the script without arguments will list the latest uploaded videos
(max 50 entries). Append a search term after the command to \"grep\" the entire
catalog of Animefreak. For example:

./animefreak-downloader.sh monogatari

Wget needs to be intalled for downloading. Mplayer (optional) for viewing
videos.

As always, please do not abuse the service.

Options:	-h 	     print this help tip"
}

PATH_1A() {
while :
do
	clear

	# Assemble a list of titles according the search term
	BOOK=$(grep -o '<a href="/watch..*</a>' book.htm |sed -e 's/<a href="/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//' | \
	grep -i -e " .*$SEARCH")

	# Count number of results
	R_COUNT=$(echo "$BOOK" | wc | awk '{print $1}')

	# Check if no results
	if [ -z "$BOOK" ]
	then
		read -p "No title found containing the word(s) $SEARCH. Search for? >> " SEARCH 2>&1
		continue
	fi

	# Print the results to screen
	echo "$BOOK" | grep -o " .*$" | awk '{print NR, $0}' | column

	# Get user input
	read -p "Found $R_COUNT results containing the word(s): $SEARCH. Type a number to select a series and press enter. (s) to search again. (q) to quit. >> " EP 2>&1

	INPUT_CHECK

	# Get page of series
	echo "$BOOK" | sed -n "$EP"p | sed 's/ .*$//' | wget -nv -U "$USER_AGENT" -i - -O title.htm

	# Get only the eisodes
	CONTENT=$(grep -i leaf title.htm | grep -o '<a href..*</a>' | sed -e 's/<a href="/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//' | \
	awk ' !x[$0]++')

	# If no episodes found
	if [ -z "$CONTENT" ]
	then
		echo "INFO: Propably movie found, using alternative path" >> log.txt # log
		PAGE=$(cat title.htm)
		PAGE_SCRAPER
		MIRROR_CHECK
		PATH_3
	else
		break
	fi
done
}

PATH_1B() {
while :
do
	clear

	# Count number of available episodes
	R_COUNT=$(echo "$CONTENT" | wc | awk '{print $1}')

	# Print episodes to screen
	echo "$CONTENT" | grep -o -i " .*$" | awk '{print NR, $0}' | column  -t | more 2>&1

	# Get user input
	read -p "Select an episode, (a) to download all, (r) to download range, (s) to make a new search, (q) to quit. >> " EP 2>&1

	# Input check
	if [ "$EP" == s ] # Search again
	then
		read -p "Search for? >> " SEARCH 2>&1
		break
	elif [ "$EP" == r ] # Download range
	then
		while :
		do
			echo "Type (c) in either field to cancel"

			# Get From input
			read -p "Download from:" EP 2>&1
			if [ "$EP" == c ]
			then
				break
			fi

			# Get To input
			read -p "To:" R_COUNT 2>&1
			if [ "$R_COUNT" == c ]
			then
				break
			fi

			# Input check
			if ! [[ "$EP" =~ ^[0-9]+$ ]]
			then
				echo "Not a number"
				sleep 1
				continue
			elif ! [[ "$R_COUNT" =~ ^[0-9]+$ ]] 
			then
				echo "Not a number"
				sleep 1
				continue
			elif [ "$EP" -eq 0 -o "$R_COUNT" -eq 0 ]
			then
				echo "Can not be 0 either field"
				sleep 1
				continue
			elif [ "$EP" -ge "$R_COUNT" ]
			then
				echo "From: can not be greater or equal to To:"
				sleep 1
				continue
			else
				BATCH
				break
			fi
		done
		continue
	elif [ "$EP" == a ] # Download all
	then
		EP=1
		BATCH
		continue
	fi
	INPUT_CHECK

	# Get page
	PAGE=$(echo "$CONTENT" | sed -n "$EP"p | sed 's/ .*$//' | wget -nv -U "$USER_AGENT" -i - -O -)

	PAGE_SCRAPER
	MIRROR_CHECK
	PATH_3
done
}

PATH_2() {
while :
do
	clear

	# Count number of available episodes
	R_COUNT=$(echo "$CONTENT" | wc | awk '{print $1}')

	# Print results to screen and episode selection
	echo "$CONTENT" | grep -o " .*$" | awk '{print NR, $0}' | more 2>&1

	# Get user input
	read -p "Type a number to select an episode and press enter. Press (q) to quit. >> " EP 2>&1

	INPUT_CHECK

	# Get page
	PAGE=$(echo "$CONTENT" | sed -n "$EP"p | sed 's/ .*$//' | wget -nv -U "$USER_AGENT" -i - -O -)

	PAGE_SCRAPER
	MIRROR_CHECK
	PATH_3
done
}

PATH_3() {
while :
do
	# If only one mirror found
	if [ "$M_COUNT" -eq 1 ]
	then
		M_NUM=1
		M_FILTER

	# If more than one mirror found
	else
		clear
		echo "$MIRRORS" | grep -o -e "http://[0-9].*[0-9]/" -e animefreak.tv -e upload2.com -e mp4upload.com -e videobam.com -e novamov.com -e videoweed.es \
		| sed -e 's/http://' -e 's_/__g' | awk '{print NR, $0}'
		read -p "There are $M_COUNT mirrors for $TITLE Select a number and press enter, (b) to go back, (q) to quit. >> " M_NUM 2>&1
		if [ "$M_NUM" == q ]
		then
			echo "exit"
			exit
		elif [ "$M_NUM" == b ]
		then
			break
		elif ! [[ "$M_NUM" =~ ^[0-9]+$ ]] ; 
		then
			echo "Not a number"
			sleep 1
			continue
		elif [ "$M_NUM" == 0 -o "$M_NUM" -gt "$M_COUNT" ]
		then
			echo "Not a valid number"
			sleep 1
			continue
		else
			M_FILTER
		fi
	fi

	# Download or play the file
	while :
	do
		read -p "View (v) or save (s) video? (b) to go back (q) to quit. >> " CHOICE 2>&1
		if [ "$CHOICE" == q ]
		then
			echo "exit"
			exit
		elif [ "$CHOICE" == b ]
		then
			break
		elif [ "$CHOICE" == s ]
		then
			DOWNLOADER
			break
		elif [ "$CHOICE" == v ]
		then
			mplayer -msglevel all=1 -user-agent "$USER_AGENT" "$URL"
			break
		else
			echo "Not a valid option"
			sleep 1
			continue
		fi
	done

	# If only one mirror available go back
	if [ "$M_COUNT" -eq 1 ]
	then
		break

	# Or try a different mirror
	else
		while :
		do
			read -p "Try a different mirror? (y) for yes (n) to go back (q) to quit. >> " DIFF 2>&1
			if [ "$DIFF" == y -o "$DIFF" == n ]
			then
				break
			elif [ "$DIFF" == q ]
			then
				echo "exit"
				exit
			else
				echo "Not a valid option."
				sleep 1
				continue
			fi
		done
		if [ "$DIFF" == y ]
		then
			continue
		else
			break
		fi
	fi
done
}

if [ "$1" == -h ]
then
	HELP
	exit
elif [ "$SEARCH" ] 
then
	# Get entire catalog if not allready downloaded
	if ! [ -s book.htm ]
	then 
		echo "Getting anime catalog."
		wget -nv -U "$USER_AGENT" "http://www.animefreak.tv/book" -O book.htm
	fi

	while :
	do
		PATH_1A
		PATH_1B
	done
else
	echo "Getting latest episodes."

	# Get the latest episodes
	CONTENT=$(wget -nv -U "$USER_AGENT" 'http://www.animefreak.tv/tracker' -O - | grep -o '"/watch.*</a>' | grep -i -e episode -e movie | \
	sed -e 's/"/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//')

	PATH_2
fi
