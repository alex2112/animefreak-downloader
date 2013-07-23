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
	# Get all series titles and urls into book_search based on search term.
	grep -o '<a href="/watch..*</a>' book.htm |sed 's/<a href="/http:\/\/www.animefreak.tv/'| sed 's/">/ /' |sed 's/<\/a>//' | grep -i " .*$searchterm" 2>/dev/null > book_search
	
	# Print results to screen.
	grep -o " .*$" book_search | awk '{print NR, $0}' | column

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
			animetitle="`sed -n $(echo $num)p book_search | grep -o " .*$"`"
			sed -n $(echo $num)p book_search | sed 's/ .*$//' | wget -q -i - -O - | grep -i leaf |grep -o '<a href..*</a>' | sed 's/<a href="/http:\/\/www.animefreak.tv/' | sed 's/">/ /' |sed 's/<\/a>//' |awk ' !x[$0]++' > series_episodes
			break
		fi
	done
}

function path1b {
	while :
	do
		clear
		echo "$animetitle"
		grep -o -i " .*$" series_episodes | awk '{print NR, $0}' |column  -t |more
		echo " Select an episode, press enter to quit, b to go back."

		read num
		if [ -z $num ]
		then
			echo "exit"
			exit
		elif [ $num == b ]
		then
			path1a
		elif ! [[ "$num" =~ ^[0-9]+$ ]] ;
		then
			echo "Not a number"
			sleep 1
			clear
			continue
		else
			filename="`sed -n $(echo $num)p series_episodes | grep -o ' .*$' | sed 's/ //' | sed 's/ /_/g' | sed 's/$/.mp4/'`"
			sed -n $(echo $num)p series_episodes | sed 's/ .*$//' | wget -q -i - -O ep
			grep "%3Fst%3D" ep > mirrors
                        grep "var temp" ep > mirrors_alt
			break
		fi
	done
}

function path2 {
	while :
	do
		# Print results to screen
		grep -o " .*$" latest | awk '{print NR, $0}' | more

		echo "*********************************************************"
		echo "* Select a number and press enter or just enter to quit *"
		echo "*********************************************************"

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
			filename="`sed -n $(echo $num)p latest | grep -o ' .*$' | sed 's/ //' | sed 's/ /_/g' | sed 's/$/.mp4/'`"
			sed -n $(echo $num)p latest | sed 's/ .*$//' | wget -q -i - -O ep
			grep "%3Fst%3D" ep > mirrors
			grep "var temp" ep > mirrors_alt
			break
		fi
	done
}

function mirror {
mirrors="`wc mirrors |awk {'print $1'}`"
if [ $mirrors -eq 1 ]
then
	mirror_num=1
	video_url
elif [ $mirrors -eq 0 ]
then
	video_url2
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
		video_url
		break
	fi
	done
fi	
}

function video_url {
ip="`sed -n $(echo $mirror_num)p mirrors | grep -o "http..*%2F" | sed 's/http%3A%2F%2F//' |sed 's/%2F//'`"
title="`sed -n $(echo $mirror_num)p mirrors | grep -o "%2F.*%3Fst%3D" | sed 's/%2F%2F.*%2F//' | sed 's/%3Fst%3D//' |sed 's/+/ /g'`"
key="`sed -n $(echo $mirror_num)p mirrors | grep -o "%3Fst%3D.*3D.........." | sed 's/%3F/?/' | sed 's/%3D/=/g'|sed 's/%26/\&/g'`"
}

function video_url2 {
ip="78.152.42.206"
title="`grep 'var temp' mirrors_alt | grep -o -i 'file%3D.*.%26e' | sed 's/file%3D//' | sed 's/%26e//' | sed 's/+/ /g'`"
st="`grep 'var temp' mirrors_alt | grep -i -o 'st%3d.*frame%3E%0D' | sed 's/st%3D//' |sed 's/%22%3E%3C%2Fiframe%3E%0D//'`"
e="`grep 'var temp' mirrors_alt | grep -i -o '%26e%3d.*%26st' | sed 's/%26e%3D//' |sed 's/%26st//'`"
key="?st=$st&e=$e"
}

function downloader {
while :
do
echo "View (v) or save (s) video? Press enter to exit."

read choice

if [ -z $choice ]
then
	echo "exit"
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

# Main
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
		downloader
	done
else
	wget -q 'http://www.animefreak.tv/tracker' -O - | grep -o '"/watch.*</a>' | grep -i -e episode -e movie | sed 's/"/http:\/\/www.animefreak.tv/' |sed 's/">/ /' |sed 's/<\/a>//' > latest
	while :
	do
		path2
		mirror
		downloader
	done
fi
