#!/bin/bash

### CONFIGURATION ###
download_path=$HOME/Downloads # Defaults: $HOME/Downloads
temp_path=/tmp/animefreak_downloader # Defaults: /tmp/animefreak_downloader
user_agent="Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:22.0) Gecko/20100101 Firefox/22.0"
### END CONFIGURATION ###

search_term=$@ # DO NOT TOUCH THIS!

# Change directory
cd $temp_path 2>/dev/null || mkdir -p $temp_path && cd $temp_path
# Enable error loging to file
exec 2>log.txt


mirror_detect() {
# Get a episode title
episode_title=$(echo "$episodes" | sed -n "$ep"p | grep -o ' .*$' | sed 's/ //')
# Get filename
filename=$(echo "$episodes" | sed -n "$ep"p | grep -o ' .*$' | sed -e 's/ //' -e 's/ /_/g' -e 's/$/.mp4/')
# Mirror detection pass 1
pass1=$(echo "$episodes" | sed -n "$ep"p | sed 's/ .*$//' | wget -nv -U "$user_agent" -i - -O - | grep -e Fst -e upload2 -e mp4upload -e videobam)
# Mirror detection pass 2
url_decoder "$pass1" | grep -o "http.*animefreak.tv.*&st=......................" > mirrors.txt #animefreak
url_decoder "$pass1" | grep -o '"http.*upload2.*embed/.*$' | sed -e 's/"//g' -e 's/><\/iframe.*$//' >> mirrors.txt #upload2.com
url_decoder "$pass1" | grep -o "http.*mp4upload.*\.html" >> mirrors.txt #mp4upload.com
url_decoder "$pass1" | grep -o "http.*?st=.*&e=.........." >> mirrors.txt #direct
url_decoder "$pass1" | grep -o "http://videobam..*" | sed 's/"/ /g' | awk {'print $1'} >> mirrors.txt #videobam
# Gather all detected mirrors in one place
mirrors=$(sort -u mirrors.txt | sed '/^$/d')
# Count how many mirrors detected
mirror_count=$(echo "$mirrors" | wc  | awk {'print $1'})
# For dubbuging
echo "INFO: Number of mirrors detected $mirror_count which are: " >> log.txt
echo "$mirrors" >> log.txt
}

mirror() {
while :
do
	# If only one mirror found
	if [ "$mirror_count" -eq 1 ]
	then
		mirror_num=1
		mirror_type
		break
	fi
	# If more than one mirror found
	clear
	read -p "There are $mirror_count mirrors for $episode_title. Select a number and press enter, (b) to go back, (q) to quit. >> " mirror_num 2>&1
	if [ "$mirror_num" == q ]
	then
		echo "exit"
		exit
	elif [ "$mirror_num" == b ]
	then
		break
	elif ! [[ "$mirror_num" =~ ^[0-9]+$ ]] ; 
	then
		echo "Not a number"
		sleep 1
		continue
	elif [ "$mirror_num" == 0 -o "$mirror_num" -gt "$mirror_count" ]
	then
		echo "Not a valid number"
		sleep 1
		continue
	else
		mirror_type
		break
	fi
done
}

mirror_type() {
# Choose the appropriate path according to the mirror selected
type_of_mirror=$(echo "$mirrors" | sed -n "$mirror_num"p | grep -o -e animefreak.tv -e upload2 -e mp4upload -e videobam)
if [ "$type_of_mirror" == "animefreak.tv" ]
then
	downlink=$(wget -nv -U "$user_agent" "$(echo "$mirrors" | sed -n "$mirror_num"p)" -O - | grep movie)
	url=$(url_decoder "$downlink" | grep -o -e "=http..*st=......................" -e "=http..*e=.........." | sed 's/=//')
elif [ "$type_of_mirror" == upload2 ]
then
	downlink=$(wget -nv -U "$user_agent" "$(echo "$mirrors" | sed -n "$mirror_num"p)" -O - | grep movie)
	url=$(echo "$downlink" | grep -o "video=http..*" | sed 's/rating=/\n/' | sed -n 1p | sed -e 's/video=//' -e 's/&$//')
elif [ "$type_of_mirror" == mp4upload ]
then
	downlink=$(wget -nv -U "$user_agent" "$(echo "$mirrors" | sed -n "$mirror_num"p)" -O - | grep "'file'")
	url=$(echo "$downlink" | grep -o "http..*'" | sed "s/'//")
elif [ "$type_of_mirror" == videobam ]
then
	downlink=$(wget -nv -U "$user_agent" "$(echo "$mirrors" | sed -n "$mirror_num"p)" -O - | grep low:)
	url=$(echo "$downlink" | grep -o "http.*" | sed "s/[,']//g")
else
	type_of_mirror=direct
	url=$(echo "$mirrors" | sed -n "$mirror_num"p)
fi
# For debbuging
echo "INFO: $type_of_mirror path chosen with url $url" >> log.txt
}

downloader() {
# Download or play the file
while :
do
	read -p "View (v) or save (s) video? (b) to go back (q) to quit. >> " choice 2>&1
	if [ -z "$choice" ]
	then
		sleep 1
		continue
	elif [ "$choice" == q ]
	then
		echo "exit"
		exit
	elif [ "$choice" == b ]
	then
		break
	elif [ "$choice" == s ]
	then
		echo "Now saving $filename to $download_path"
		wget -U "$user_agent" "$url" -O $download_path/$filename 2>&1
		break
	elif [ "$choice" == v ]
	then
		mplayer -msglevel all=1 -user-agent "$user_agent" "$url"
		break
	else
		echo "Not a valid option"
		sleep 1
		continue
	fi
done
}

diff_mirror() {
# Try a different mirror if available
while :
do
	clear
	read -p "Try a different mirror? (y) for yes (n) to go back (q) to quit. >> " diffmir 2>&1
	if [ "$diffmir" == y -o "$diffmir" == n ]
	then
		break
	elif [ "$diffmir" == q ]
	then
		echo "exit"
		exit
	else
		echo "Not a valid option."
		sleep 1
		continue
	fi
done
}

url_decoder() {
local d=${1//+/ }; printf '%b' "${d//%/\x}";
}

help_page() {
echo "Usage: animefreak.sh [OPTION]... [SEARCH_TERM]...
View or download videos from Animefreak.tv.

Calling the script without arguments will list the latest uploaded videos (max 50 entries).

Append a search term after the command to \"grep\" the entire catalog of Animefreak.
For example: ./animefreak-downloader.sh monogatari

Wget needs to be intalled for downloading. Mplayer (optional) for viewing videos.

As always, please do not abuse the service.

Options:
	
	-h 	     print this help tip"
}

if [ $1 == "-h" ]
then
	help_page
	exit
elif [ "$search_term" ] 
then
	# Get entire catalog and search
	if ! [ -s book.htm ]
	then 
		echo "Getting anime catalog."
		wget -nv -U "$user_agent" "http://www.animefreak.tv/book" -O book.htm
	fi
	while :
	do
		while :
		do
			clear
			# Assemble a list of titles according the search term
			list=$(grep -o '<a href="/watch..*</a>' book.htm |sed -e 's/<a href="/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//' | \
			grep -i -e " .*$search_term")
			# Count number of results
			num_of_results=$(echo "$list" | wc | awk '{print $1}')
			if [ -z "$list" ]
			then
				# No title found
				read -p "No title found containing the word(s) $search_term. Search for:" search_term 2>&1
				continue
			elif [ "$num_of_results" -eq 1 ]
			then
				# Only one title found
				series=1
				episodes=$(echo "$list" | sed -n "$series"p | sed 's/ .*$//' | wget -nv -U "$user_agent" -i - -O - | grep -i leaf | \
				grep -o '<a href..*</a>' | sed -e 's/<a href="/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//' | awk ' !x[$0]++')
				break
			else
				# Print the results to screen
				echo "$list" | grep -o " .*$" | awk '{print NR, $0}' | column
				read -p "Found $num_of_results results containing the word(s): $search_term. Type a number to select a series or (s) to search again then press enter. Press (q) to quit. >> " series 2>&1
				# Series selection
				if [ -z $series ]
				then
					sleep 1
					continue
				elif [ "$series" == q ]
				then
					echo "exit" 
					exit
				elif [ $series == s ]
				then
					read -p "Search for what? >> " search_term 2>&1
					continue
				elif ! [[ "$series" =~ ^[0-9]+$ ]]
				then
					echo "Not a number"
					sleep 1
					continue
				elif [ "$series" -gt "$num_of_results"  -o  "$series" -eq 0 ]
				then
					echo "Not a valid number"
					sleep 1
					continue
				else
					echo "Getting episode list."
					episodes=$(echo "$list" | sed -n "$series"p | sed 's/ .*$//' | wget -nv -U "$user_agent" -i - -O - | grep -i leaf | \
					grep -o '<a href..*</a>' | sed -e 's/<a href="/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//' | \
					awk ' !x[$0]++')
					break
				fi
			fi
		done
		while :
		do
			# Print episodes tou screen
			clear
			echo "$episodes" | grep -o -i " .*$" | awk '{print NR, $0}' | column  -t | more 2>&1
			if [ "$num_of_results" -eq 1 ]
			then
				read -p "Select an episode, (s) to make a new search, (q) to quit. >> " ep 2>&1
			else
				read -p "Select an episode, (b) to go back to search, (q) to quit. >> " ep 2>&1
			fi
			# Episode selection
			if [ "$ep" == q ]
			then
				echo "exit"
				exit
			elif [ "$ep" == s ]
			then
				read -p "Search for what? >> " search_term 2>&1
				break
			elif [ "$ep" == b -a "$num_of_results" != 1 ]
			then
				break
			elif ! [[ "$ep" =~ ^[0-9]+$ ]]
			then
				echo "Not a number"
				sleep 1
				continue
			else
				mirror_detect
				# If no mirrors found
				if [ -z "$mirrors" ]
				then
					read -p "Can't detect a working mirror :(. Press enter to continue." 2>&1
					continue
				fi
			fi
			while :
			do
				mirror
				if [ "$mirror_num" == b ]
				then
					break
				fi
				downloader
				# If only one mirror found go back
				if [ "$mirror_count" -eq 1 ]
				then
					break
				else
					diff_mirror
				fi
				# Choose a different mirror
				if [ "$diffmir" == y ]
				then
					continue
				else
					break
				fi
			done
		done
	done
else
	# Get the latest episodes
	echo "Getting latest episodes."
	# Assemble a list of the latest episodes
	episodes=$(wget -nv -U "$user_agent" 'http://www.animefreak.tv/tracker' -O - | grep -o '"/watch.*</a>' | grep -i -e episode -e movie | \
	sed -e 's/"/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//')
	while :
	do
		clear
		# Count number of available episodes
		num_of_results=$(echo "$episodes" | wc | awk '{print $1}')
		# Print results to screen and episode selection
		echo "$episodes" | grep -o " .*$" | awk '{print NR, $0}' | more 2>&1
		read -p "Type a number to select an episode and press enter. Press (q) to quit. >> " ep 2>&1
		if [ "$ep" == q ]
		then
			echo "exit"
			exit
		elif ! [[ "$ep" =~ ^[0-9]+$ ]]
		then
			echo "Not a number"
			sleep 1
			continue
		elif [ "$ep" -gt "$num_of_results" -o "$ep" -eq 0 ]
		then
			echo "Not a valid number"
			sleep 1
			continue
		else
			mirror_detect
			# If no mirrors found
			if [ -z "$mirrors" ]
			then
				read -p "Can't detect a working mirror :(. Press enter to go back..." 2>&1
				continue
			fi
		fi
		while :
		do
			mirror
			if [ "$mirror_num" == b ]
			then
				break
			fi
			downloader
			# If only one mirror found go back
			if [ "$mirror_count" -eq 1 ]
			then
				break
			else
				diff_mirror
			fi
			# Choose a different mirror
			if [ "$diffmir" == y ]
			then
				continue
			else
				break
			fi
		done
	done
fi
