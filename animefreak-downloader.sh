#!/bin/bash

download_path=$HOME/Downloads # Set your prefered download path here. Default value: $HOME/Downloads
cache_path=/tmp/animefreak_downloader # Set the path for various cached files. /tmp/some_dir and ~/.cache/some_dir are recommended. Default value: /tmp/animefreak_downloader

searchterm=$@ # DO NOT TOUCH THIS!

cd $cache_path 2>/dev/null || mkdir -p $cache_path && cd $cache_path

# Help
if [ $1 == "-h" ] 2>/dev/null
then
	echo "Usage: animefreak.sh [OPTION]... [SEARCH_TERM]..."
	echo "View or download videos from Animefreak.tv."
	echo
	echo "Calling the script without arguments will list the 20 latest uploaded videos."
	echo
	echo "Use a search term (one word only) to \"grep\" the entire catalog of Animefreak."
	echo
	echo "wget needs to be intalled for downloading. Mplayer (optional) for viewing videos."
	echo
	echo "Options:"
	echo
	echo " 	-h 			     print this help tip"
	exit
fi

# Functions
function path1a {
	while :
	do
	clear
	# Get all series titles and urls into a file based on search term.
	grep -o '<a href="/watch..*</a>' book.htm |sed 's/<a href="/http:\/\/www.animefreak.tv/'| sed 's/">/   /' |sed 's/<\/a>//' | grep -i "   .*$searchterm" 2>/dev/null > urls_titles
	
	# Make a urls only file based on search term again.
	cat urls_titles | awk {'print $1'} > urls_only

	# Print results to screen.
	cat urls_titles | sed 's/http..*   //' |awk '{print NR, $0}' |column

		echo "****************************************************************************"
		echo "* Type a number to select a series or (s) to search again then press enter.*"
		echo "*     If no results shown please use only a single word search term.       *" 
		echo "*          If to many results shown please be more specific.               *"
		echo "*                           Press enter to quit.                           *"
		echo "****************************************************************************"
		echo "You searched for: "$searchterm""
		read num

		if [ -z $num ]
		then
			echo "exit" 
			exit
		elif [ $num == s ]
		then
			echo "Search for what?"
			read searchterm
			continue
		elif ! [[ "$num" =~ ^[0-9]+$ ]] ;
		then
			echo "Not a number"
			sleep 1
			clear
			continue
		else
			wget -q `sed -n $(echo $num)p urls_only` -O series
			break
		fi
	done
}

function path1b {
	# Get anime title
	animetitle="`grep -o "<title>..*|" series |sed 's/<title>Watch //' |sed 's/ Online |//'`"
	# Get episodes urls and titles.
	grep -i leaf series |grep -o '<a href..*</a>' | sed 's/<a href="/http:\/\/www.animefreak.tv/' | sed 's/">/ /' |sed 's/<\/a>//' |awk ' !x[$0]++' > episodes_url_titles
	# Get urls only to file.
	awk {'print $1'} episodes_url_titles > episodes_url_only

	while :
	do
		clear
		echo "$animetitle"
		# Print numbered episodes to screen.
		grep -o -i " ..*$" episodes_url_titles | awk '{print NR, $0}' |column  -t |more
		echo " Select an episode, press enter to quit, b to go back."

		read num
		if [ -z $num ]
		then
			echo "exit"
			exit
		elif [ $num == b ]
		then
			path1a
			break
		elif ! [[ "$num" =~ ^[0-9]+$ ]] ;
		then
			echo "Not a number"
			sleep 1
			clear
			continue
		else
			wget -q `sed -n $(echo $num)p episodes_url_only` -O ep
			break
		fi
	done
}

function path2 {
	while :
	do
		# Print the titles on screen.
		grep -o '<a href="/watch..*</a>' freak_tracker.htm |grep -m 20 -i episode | grep -i -o '>..*</a>' |sed 's/>//' |sed 's/<\/a>//' |awk '{print NR, $0}'

		echo "*******************************************************************"
		echo "* Select a number from 1-20 and press enter or just enter to quit *"
		echo "*******************************************************************"

		read num

		if [ -z $num ]
		then
			echo "exit"
			exit
		elif ! [[ "$num" =~ ^[0-9]+$ ]] ;
		then
			echo "Not a number"
			sleep 1
			clear
			continue
		else
			wget -q `sed -n $(echo $num)p 20_eps` -O ep
			break
		fi
	done
}

function mirror {
grep "%3Fst%3D" ep > mirrors
mirrors="`wc mirrors |awk {'print $1'}`"
if [ $mirrors -eq 1 ]
then
	sed -n '1p' mirrors > single_mirror
elif [ $mirrors -eq 0 ]
then
	echo "Seems i can't find a valid mirror for this episode. :("
	sleep 1
	continue
else
	while :
	do
	echo "There are $mirrors mirrors for this episode"
	echo "Select a number and press enter"
	read mirror_num
	if ! [[ "$mirror_num" =~ ^[0-9]+$ ]] ; 
	then
		echo "Not a number"
		sleep 1
		clear
		continue
	elif [ $mirror_num == 0 ]
	then
		echo "Not a valid number"
		continue
	elif [ $mirror_num -gt $mirrors ]
	then
		echo "Not a valid number"
		continue
	else
		sed -n $(echo $mirror_num)p mirrors > single_mirror
		break
	fi
	done
fi	
}

function parser {
ip="`grep "%3Fst%3D" single_mirror | grep -o "http..*%2F" | sed 's/http%3A%2F%2F//' |sed 's/%2F//'`"
title="`grep "%3Fst%3D" single_mirror | grep -o "%2F.*%3Fst%3D" | sed 's/%2F%2F.*%2F//' | sed 's/%3Fst%3D//' |sed 's/+/ /g'`"
key="`grep -o "%3Fst%3D.*3D.........." single_mirror | sed 's/%3F/?/' | sed 's/%3D/=/g'|sed 's/%26/\&/g'`"
filename="`grep -o "<title>..*|" ep |sed 's/<title>Watch //' |sed 's/ Online |/.mp4/' |sed 's/ /_/g'`"
}

function downloader {
while :
do
echo "View (v) or save (s) video? Press enter to exit."

read choice

if [ -z $choice ]
then
	exit
elif [ "$choice" == s ]
then
	echo "Now saving" $filename "to $download_path"
	wget "http://$ip/$title$key" -O $download_path/$filename
	break
elif [ "$choice" == v ]
then
	mplayer "http://$ip/$title$key"
	break
else
	echo "Not a valid key"
	sleep 1
	continue
fi
done
}

function jump_back {
echo
echo "Download another video? Press (y) for yes or just enter to exit"
read choice
if [ -z $choice ]
then
	echo "exit" 
	exit
elif [ "$choice" == y ]
then
	continue
else
	echo "exit"
	exit
fi
}

# Main if_then_else
if [ -n "$searchterm" ] 
then
	if [ -f book.htm ]
	then 
		clear
	else
		wget -q "http://www.animefreak.tv/book" -O book.htm
		clear
	fi
	path1a
	while :
	do
		path1b
		mirror
		parser
		downloader
		jump_back
	done
else
	wget -q 'http://www.animefreak.tv/tracker' -O freak_tracker.htm
	clear
	# Save 20 latest episodes urls to file.
	grep -o '<a href="/watch..*"' freak_tracker.htm |grep -m 20 -i episode |sed 's/<a href="/http:\/\/www.animefreak.tv/' |sed 's/"//'  > 20_eps
	while :
	do
		path2
		mirror
		parser
		downloader
		jump_back
	done
fi
