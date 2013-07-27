#!/bin/bash

download_path=$HOME/Downloads # Defaults: $HOME/Downloads
temp_path=/tmp/animefreak_downloader # Defaults: /tmp/animefreak_downloader
searchterm=$@ # DO NOT TOUCH THIS!

cd $temp_path 2>/dev/null || mkdir -p $temp_path && cd $temp_path

function mirror {
num_of_mirrors=$(echo "$mirrors" | wc  | awk {'print $1'})
# echo "$mirrors" # debug
if [ $num_of_mirrors -eq 1 ]
then
	mirror_type=$(echo $mirrors | grep -o "var tempfile")
	if [ "$mirror_type" == "var tempfile" ]
	then
		# echo "video_url2" # debug
		mirror_num=1
		video_url2
	else
		# echo "video_url" # debug
		mirror_num=1
		video_url
	fi
elif [ $num_of_mirrors -eq 0 ]
then
	read -p "Can't detect a working mirror :(. Press enter to continue..."
	break
else
	while :
	do
		clear
		echo "There are $num_of_mirrors mirrors for $animetitle"
		echo "Select a number and press enter"
		read mirror_num
		if [ "$mirror_num" == q ]
		then
			echo "exit"
			exit
		elif ! [[ "$mirror_num" =~ ^[0-9]+$ ]] ; 
		then
			echo "Not a number"
			sleep 1
			continue
		elif [ "$mirror_num" == 0 -o "$mirror_num" -gt "$num_of_mirrors" ]
		then
			echo "Not a valid number"
			sleep 1
			continue
		else
			mirror_type=$(echo "$mirrors" | sed -n "$mirror_num"p | grep -o "var tempfile")
			if [ "$mirror_type" == "var tempfile" ]
			then
				# echo "video_url2" # debug
				video_url2
				break
			else
				# echo "video_url" # debug
				video_url
				break
			fi
		fi
	done
fi	
}

function video_url {
url=$(echo "$mirrors" | sed -n "$mirror_num"p | url_decoder | grep -o "http..*e=..........")
# echo $url # debug
}

function video_url2 {
url=$(wget -q "$(echo "$mirrors" | sed -n "$mirror_num"p | url_decoder | grep -o "http..*st=......................")" -O - | grep -m 1 -oi "file=..*..&captions" | url_decoder | sed -e 's/file=//' -e 's/\&captions//')
# echo $url # debug
}

function downloader {
while :
do
	echo "View (v) or save (s) video? (b) to go back (q) to quit."
	read choice
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
		wget "$url" -O $download_path/$filename
		break
	elif [ "$choice" == v ]
	then
		mplayer -msglevel all=-1 "$url"
		# mplayer "$url" # debug
		break
	else
		echo "Not a valid option"
		sleep 1
		continue
	fi
done
}

function diff_mirror {
while :
do
	clear
	echo "Try a different mirror? (y) for yes (n) to go back (q) to quit."
	read diffmir
	if [ "$diffmir" == y -o n ]
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

function url_decoder {
sed -e 's/%21/!/g'  -e 's/%23/#/g' -e 's/%24/$/g' -e 's/%26/\&/g' -e "s/%27/'/g" -e 's/%28/(/g' -e 's/%29/)/g' -e 's/%2A/*/g' -e 's/%2B/+/g' -e 's/%2C/,/g' -e 's/%2F/\//g' -e 's/%3A/:/g' -e 's/%3B/;/g' -e 's/%3D/=/g' -e 's/%3F/?/g' -e 's/%40/@/g' -e 's/%5B/[/g' -e 's/%5D/]/g' -e 's/+/ /g'
}

# function urldecoder {
# local d=${1//+/ }; printf '%b' "${d//%/\x}";
# }

function help_page {
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

if [ $1 == "-h" ] 2>/dev/null
then
	help_page
	exit
elif [ -n "$searchterm" ] 
then
	if [ -f book.htm ]
	then 
		clear
	else
		wget -q "http://www.animefreak.tv/book" -O book.htm
		clear
	fi
	while :
	do
		while :
		do
			clear
			book_search=$(grep -o '<a href="/watch..*</a>' book.htm |sed -e 's/<a href="/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//' | grep -i -e " .*$searchterm" 2>/dev/null)
			num_of_results=$(echo "$book_search" | wc | awk '{print $1}')
			if [ -z "$book_search" ]
			then
				echo "No title found containing the word(s) $searchterm."
				sleep 1
				echo "Search for what?"
				read searchterm
				continue
			elif [ "$num_of_results" -eq 1 ]
			then
				series=1
				series_episodes=$(echo "$book_search" | sed -n "$series"p | sed 's/ .*$//' | wget -q -i - -O - | grep -i leaf | grep -o '<a href..*</a>' | sed -e 's/<a href="/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//' |awk ' !x[$0]++')
				break
			else
				echo "$book_search" | grep -o " .*$" | awk '{print NR, $0}' | column
				echo "Type a number to select a series or (s) to search again then press enter. Press (q) to quit."
				echo "Found $num_of_results results containing the word(s): $searchterm"
				read series
				if [ -z $series ] 2>/dev/null
				then
					sleep 1
					continue
				elif [ "$series" == q ] 2>/dev/null
				then
					echo "exit" 
					exit
				elif [ $series == s ] 2>/dev/null
				then
					echo "Search for what?"
					read searchterm
					continue
				elif ! [[ "$series" =~ ^[0-9]+$ ]] 2>/dev/null
				then
					echo "Not a number"
					sleep 1
					continue
				elif [ "$series" -gt "$num_of_results"  -o  "$series" -eq 0 ] 2>/dev/null
				then
					echo "Not a valid number"
					sleep 1
					continue
				else
					series_episodes=$(echo "$book_search" | sed -n "$series"p | sed 's/ .*$//' | wget -q -i - -O - | grep -i leaf | grep -o '<a href..*</a>' | sed -e 's/<a href="/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//' |awk ' !x[$0]++')
					break
				fi
			fi
		done
		while :
		do
			clear
			echo "$series_episodes" | grep -o -i " .*$" | awk '{print NR, $0}' |column  -t |more
			if [ "$num_of_results" -eq 1 ]
			then
				echo "Select an episode, (q) to quit."
			else
				echo "Select an episode, (q) to quit, (b) to go back."
			fi
			read ep
			if [ "$ep" == q ] 2>/dev/null
			then
				echo "exit"
				exit
			elif [ "$ep" == b -a "$num_of_results" != 1 ] 2>/dev/null
			then
				break
			elif ! [[ "$ep" =~ ^[0-9]+$ ]] 2>/dev/null
			then
				echo "Not a number"
				sleep 1
				continue
			else
				animetitle=$(echo "$series_episodes" | sed -n "$ep"p | grep -o ' .*$' | sed 's/ //')
				filename=$(echo "$series_episodes" | sed -n "$ep"p | grep -o ' .*$' | sed -e 's/ //' -e 's/ /_/g' -e 's/$/.mp4/')
				mirrors=$(echo "$series_episodes" | sed -n "$ep"p | sed 's/ .*$//' | wget -q -i - -O - | grep -e "%3Fst%3D" -e "var tempfile")
				break
			fi
		done
		while :
		do
			if [ "$ep" == b ]
			then
				break
			fi
			mirror
			downloader
			if [ "$num_of_mirrors" -eq 1 ]
			then
				break
			else
				diff_mirror
			fi
			if [ "$diffmir" == y ]
			then
				continue
			else
				break
			fi
		done
	done
else
	latest=$(wget -q 'http://www.animefreak.tv/tracker' -O - | grep -o '"/watch.*</a>' | grep -i -e episode -e movie | sed -e 's/"/http:\/\/www.animefreak.tv/' -e 's/">/ /' -e 's/<\/a>//')
	while :
	do
		while :
		do
			clear
			num_of_results=$(echo "$latest" | wc | awk '{print $1}')
			echo "$latest" | grep -o " .*$" | awk '{print NR, $0}' | more
			echo "*************************************************************************"
			echo "* Type a number to select an episode and press enter. Press (q) to quit *"
			echo "*************************************************************************"
			read laep
			if [ "$laep" == q ]
			then
				echo "exit"
				exit
			elif ! [[ "$laep" =~ ^[0-9]+$ ]] ;
			then
				echo "Not a number"
				sleep 1
				continue
			elif [ "$laep" -gt "$num_of_results" -o "$laep" -eq 0 ]
			then
				echo "Not a valid number"
				sleep 1
				continue
			else
				animetitle=$(echo "$latest" | sed -n "$laep"p | grep -o ' .*$' | sed 's/ //')
				filename=$(echo "$latest" | sed -n "$laep"p | grep -o ' .*$' | sed -e 's/ //' -e 's/ /_/g' -e 's/$/.mp4/')
				mirrors=$(echo "$latest" | sed -n "$laep"p | sed 's/ .*$//' | wget -q -i - -O - | grep -e "%3Fst%3D" -e "var tempfile")
				break
			fi
		done
		while :
		do
			mirror
			downloader
			if [ "$num_of_mirrors" -eq 1 ]
			then
				break
			else
				diff_mirror
			fi
			if [ "$diffmir" == y ]
			then
				continue
			else
				break
			fi
		done
	done
fi
