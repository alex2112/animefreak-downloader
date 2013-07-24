#!/bin/bash

download_path=$HOME/Downloads # Defaults: $HOME/Downloads
cache_path=/tmp/animefreak_downloader # Defaults: /tmp/animefreak_downloader
searchterm=$@ # DO NOT TOUCH THIS!

cd $cache_path 2>/dev/null || mkdir -p $cache_path && cd $cache_path

function path1a {
while :
do
	clear
	# Create book_search variable based on search term, containing the urls then the titles.
	book_search=$(grep -o '<a href="/watch..*</a>' book.htm |sed 's/<a href="/http:\/\/www.animefreak.tv/'| sed 's/">/ /' | sed 's/<\/a>//' | grep -i " .*$searchterm" 2>/dev/null)
	# Print results to screen.
	echo "$book_search" | grep -o " .*$" | awk '{print NR, $0}' | column
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
		animetitle=$(echo "$book_search" | sed -n $(echo $num)p | grep -o " .*$")
		series_episodes=$(echo "$book_search" | sed -n $(echo $num)p | sed 's/ .*$//' | wget -q -i - -O - | grep -i leaf | grep -o '<a href..*</a>' | sed 's/<a href="/http:\/\/www.animefreak.tv/' | sed 's/">/ /' |sed 's/<\/a>//' |awk ' !x[$0]++')
		break
	fi
done
}

function path1b {
while :
do
	clear
	echo "$animetitle"
	echo "$series_episodes" | grep -o -i " .*$" | awk '{print NR, $0}' |column  -t |more
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
		filename=$(echo "$series_episodes" | sed -n $(echo $num)p | grep -o ' .*$' | sed 's/ //' | sed 's/ /_/g' | sed 's/$/.mp4/')
		mirrors=$(echo "$series_episodes" | sed -n $(echo $num)p | sed 's/ .*$//' | wget -q -i - -O - | grep -e "%3Fst%3D" -e "var temp")
		break
	fi
done
}

function path2 {
while :
do
	# Print results to screen
	echo "$latest" | grep -o " .*$" | awk '{print NR, $0}' | more
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
		filename=$(echo "$latest" | sed -n $(echo $num)p | grep -o ' .*$' | sed 's/ //' | sed 's/ /_/g' | sed 's/$/.mp4/')
		mirrors=$(echo "$latest" | sed -n $(echo $num)p | sed 's/ .*$//' | wget -q -i - -O - | grep -e "%3Fst%3D" -e "var temp")
		break
	fi
done
}

function mirror {
num_of_mirrors=$(echo "$mirrors" | wc  | awk {'print $1'})
echo "$mirrors" # debug
if [ $num_of_mirrors -eq 1 ]
then
	mirror_type=$(echo $mirrors | grep -o "var tempfile")
	if [ "$mirror_type" == "var tempfile" ]
	then
		video_url2
	else
		video_url
	fi
elif [ $num_of_mirrors -eq 0 ]
then
	read -p "Can't find a suitable mirror :(. Press enter to continue..."
	break
else
	while :
	do
		echo "There are $num_of_mirrors mirrors for this episode"
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
		elif [ $mirror_num -gt $num_of_mirrors ]
		then
			echo "Not a valid number"
			continue
		else
			mirror_type=$(echo "$mirrors" | sed -n $(echo $mirror_num)p | grep -o "%3Fst%3D")
			if [ "$mirror_type" == "%3Fst%3D" ]
			then
				echo "video_url" # debug
				video_url
				break
			else
				echo "video_url2" # debug
				video_url2
				break
			fi
		fi
	done
fi	
}

function video_url {
ip=$(echo "$mirrors" | sed -n $(echo $mirror_num)p | grep -o "http..*%2F" | sed 's/http%3A%2F%2F//' |sed 's/%2F//')
title=$(echo "$mirrors" | sed -n $(echo $mirror_num)p | grep -o "%2F.*%3Fst%3D" | sed 's/%2F%2F.*%2F//' | sed 's/%3Fst%3D//' |sed 's/+/ /g')
key=$(echo "$mirrors" | sed -n $(echo $mirror_num)p | grep -o "%3Fst%3D.*3D.........." | sed 's/%3F/?/' | sed 's/%3D/=/g'|sed 's/%26/\&/g')
}

function video_url2 {
ip="78.152.42.206"
title=$(echo "$mirrors" | sed -n $(echo $mirror_num)p | grep -o -i 'file%3D.*.%26e' | sed 's/file%3D//' | sed 's/%26e//' | sed 's/+/ /g')
st=$(echo "$mirrors" | sed -n $(echo $mirror_num)p | grep -i -o 'st%3d.*frame%3E%0D' | sed 's/st%3D//' |sed 's/%22%3E%3C%2Fiframe%3E%0D//')
e=$(echo "$mirrors" | sed -n $(echo $mirror_num)p | grep -i -o '%26e%3d.*%26st' | sed 's/%26e%3D//' |sed 's/%26st//')
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
		mplayer -msglevel all=-1 "http://$ip/$title$key"
		break
	else
		echo "Not a valid key"
		sleep 1
		continue
	fi
done
}

function url_decoder {
sed -e 's/%21/!/g'  -e 's/%23/#/g' -e 's/%24/$/g' -e 's/%26/\&/g' -e "s/%27/'/g" -e 's/%28/(/g' -e 's/%29/)/g' -e 's/%2A/*/g' -e 's/%2B/+/g' -e 's/%2C/,/g' -e 's/%2F/\//g' -e 's/%3A/:/g' -e 's/%3B/;/g' -e 's/%3D/=/g' -e 's/%3F/?/g' -e 's/%40/@/g' -e 's/%5B/[/g' -e 's/%5D/]/g'
}

function help_page {
echo "Usage: animefreak.sh [OPTION]... [SEARCH_TERM]...
View or download videos from Animefreak.tv.

Calling the script without arguments will list the 20 latest uploaded videos.

Use a search term (one word only) to \"grep\" the entire catalog of Animefreak.

wget needs to be intalled for downloading. Mplayer (optional) for viewing videos.

Options:
	
	-h 	     print this help tip"
}

# Help
if [ $1 == "-h" ] 2>/dev/null
then
	help_page
	exit
fi

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
	latest=$(wget -q 'http://www.animefreak.tv/tracker' -O - | grep -o '"/watch.*</a>' | grep -i -e episode -e movie | sed 's/"/http:\/\/www.animefreak.tv/' |sed 's/">/ /' |sed 's/<\/a>//')
	while :
	do
		path2
		mirror
		downloader
	done
fi
