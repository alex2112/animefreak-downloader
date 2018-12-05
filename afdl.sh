#!/usr/bin/env bash

# Configuration
dl_path=$HOME/Downloads
player=mpv # mvp, vlc, cvlc, mplayer
# End configuration

config=~/.config/animefreak-downloader/config
if [ -f "$config" ]; then
	source "$config"
fi

user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:63.0) Gecko/20100101 Firefox/63.0"
base_url="https://www.animefreak.tv"
args=$@

usage="\
Interactive script for viewing or downloading videos from animefreak.tv.

Calling the script without arguments will list the latest uploaded
videos. Append a search term after the command to \"grep\" the
entire catalog. For example:

./afdl.sh full metal panic

wget needs to be intalled for downloading.
mpv/vlc (optional) for viewing videos.

Options:        -h           print this help tip"

cmd_help() {
echo "\

q	Quit
n/p	Next/Previous (latest episodes only)
b	Back to search (in catalog mode)
d 1	Download item 1
d 2 5 9	Download items 2, 5 and 9
v	Same as d except it executes \$player for playback
dr 3 8	Download range of items 3 to 8
vr	Same as dr except it executes \$player for playback
"
read -p "Press enter to continue"
}

get_catalog_titles() {
	echo "$1"\
		| grep '<li><a href.*</li>'\
		| grep -o 'https://www.animefreak.tv/watch.*'\
		| grep -o '">.*$'\
		| sed -e 's#</a></li>##' -e 's/">//'
}

get_catalog_links() {
	echo "$1"\
		| grep '<li><a href.*</li>'\
		| grep -o 'https://www.animefreak.tv/watch.*'\
		| sed 's/".*$//'
}

get_latest_ep_titles() {
	echo "$1"\
		| grep -A 3 '<div class="dl-item">'\
		| grep -A 1 href\
		| sed 's/^.*">//'\
		| tr -d '\n'\
		| sed 's/--/\n/g'\
		| sed 's/[ ][ ][ ]*/ /g'
}

get_latest_ep_links() {
	echo "$1"\
		| grep -A 2 '<div class="dl-item">'\
		| grep -o 'https://.*'\
		| sed 's/">.*$//g'
}

get_series_ep_titles() {
	line_num=$(echo "$1"\
			| grep -n '<div class="ci-ct tnContent">'\
			| grep -o '^[0-9]*')
	if [ -z "$line_num" ]; then line_num=1; fi
	echo "$1"\
		| tail -n+$line_num\
		| grep '<div class="epCheck ">' -A 6\
		| grep -A 2 'http.*$'\
		| sed 's/<a href.*//'\
		| sed 's/<\/a>//'\
		| sed -e 's/[ ][ ][ ]*//' -e '/^$/d' -e '/--/d'\
		| tac
}

get_series_ep_links() {
	line_num=$(echo "$1"\
			| grep -n '<div class="ci-ct tnContent">'\
			| grep -o '^[0-9]*')
	if [ -z "$line_num" ]; then line_num=1; fi
	echo "$1"\
		| tail -n+$line_num\
		| grep '<div class="epCheck ">' -A 6\
		| grep -o 'http.*$'\
		| sed 's/">//'\
		| tac
}

get_ep_mirrors() {
	echo "$1"\
		| grep -o  "file:.*"\
		| grep -o http.*\
		| sed 's/".*$//g'\
		| awk ' !x[$0]++'\
		| sed '/^$/d'
}

get_ep_title() {
	echo "$1"\
		| grep -o '<h1>.*</h1>'\
		| sed -e 's/<h1>//' -e 's/<\/h1>//'
}

get_ep_dir() {
	echo "$1"\
		| grep -A 1 '<h3 class="ead-title">'\
		| sed -n 2p\
		| sed 's/[ ][ ][ ]*//g'
}

get_ep_filename() {
	echo "$1"\
		| grep -o '<h1>.*</h1>'\
		| sed -e 's/<h1>//' -e 's/<\/h1>//'\
		| sed -e 's/ Episode /.ep/' -e 's/$/.mp4/' -e 's#[<>:"/\|?*]#_#g'
}

get() {
	url="$1"; out="$2"
	cmd=""
	if [ "$url" == "-" ]; then cmd="-i"; fi
	wget -q --referer="$base_url" -U "$user_agent" $cmd "$url" -O "$out"
}

dl() {
	url="$1"; dir="$2"; filename="$3"
	file_path="$dl_path/$dir"
	full_path="$file_path/$filename"
	mkdir -p "$file_path"
	wget -U "$user_agent" --referer="$base_url" "$url" -c -O "$full_path"
}

pl() {
	url="$1"
	cmd_args="-user-agent"
	if [ "$player" == vlc -o "$player" == cvlc ]; then
		cmd_args="--http-user-agent"
	fi
	"$player" "$cmd_args" "$user_agent" "$url"
}

batch() {
	# list is an array of numbers
	list=("${!1}"); url_list="$2"; action="$3"; ask=0
	item_count=$(echo "$url_list" | wc -l)
	for i in ${list[*]}; do
		if ! [[ "$i" =~ ^[0-9]+$ ]]; then continue; fi
		if [ "$i" -gt "$item_count" -o "$i" -eq 0 ]; then continue; fi
		ep_page=$(echo "$url_list" | sed -n "$i"p | get - -)
		mirrors=$(get_ep_mirrors "$ep_page")
		if [ -z "$mirrors" ]; then
			if [ "$ask" -eq 1 ]; then continue; fi
			read -p "No mirrors found. (b) to go back, enter to continue and don't ask again. >> " a
			if [ "$a" == b ]; then break
			else ask=1; continue; fi
		fi
		title=$(get_ep_title "$ep_page")
		dir=$(get_ep_dir "$ep_page")
		filename=$(get_ep_filename "$ep_page")
		for url in "$mirrors"; do

			if [ "$action" == d -o "$action" == dr ]; then
				util=wget
				dl "$url" "$dir" "$filename"
			elif [ "$action" == v -o "$action" == vr ]; then
				util="$player"
				pl "$url"
			fi

			exit_code=$?
			if [ "$exit_code" == 4 -a "$player" == "mpv" ]; then break
			elif [ "$exit_code" != 0 ]; then
				echo "$util exited with exit code: $exit_code"
				continue
			fi
			break
		done
	done
}

main() {
	titles="$1"; links="$2"; selection="$3"
	while :
	do
		echo
		echo "$titles" | awk '{print NR, $0}' | more
		read -a input -p "[$selection] (h) for help. >> "
		a=${input[0]}

		if [ "$a" == h ]; then cmd_help
		elif [ "$a" == q ]; then exit
		elif [ "$a" == b ]; then [ "$selection" ] && break
		elif [ "$a" == n -o "$a" == p ]; then
			if [ "$selection" ]; then continue; fi
			if [ "$a" == n ]; then page_count=$(expr $page_count + 1); fi
			if [ "$a" == p ]; then page_count=$(expr $page_count - 1); fi
			if [ "$page_count" -lt 1 ]; then page_count=1; continue; fi
			page=$(get "$base_url/home/latest-episodes/page/$page_count" -)
			titles=$(get_latest_ep_titles "$page")
			links=$(get_latest_ep_links "$page")
		elif [ "$a" == d -o "$a" == v ]; then
			batch input[*] "$links" $a
		elif [ "$a" == dr -o "$a" == vr ]; then
			begin=${input[1]}
			end=${input[2]}
			[ "$begin" -gt "$end" ] && continue
			array_start=0
			while [ "$begin" -le "$end" ]; do
				arr[$array_start]=$begin
				begin=$(expr $begin + 1)
				array_start=$(expr $array_start + 1)
			done
			batch arr[*] "$links" $a
		fi
	done
}

if [ "$1" == -h ]; then
	echo "$usage"
	exit
elif [ "$args" ]; then
	search="$args"
	page=$(get "$base_url/home/anime-list" -)
	catalog_links=$(get_catalog_links "$page")
	catalog_titles=$(get_catalog_titles "$page")
	results=$(echo "$catalog_titles" | grep -i "$search")
	item_count=$(echo "$results" | wc -l)
	while :
	do
		echo "$results" | awk '{print NR, $0}' | more 2>&1
		read -p "Select (1-$item_count), (s) search again. >> " a

		if [ "$a" == q ]; then exit; fi
		if [ "$a" == s ]; then
			read -p "Search for?>> " search
			results=$(echo "$catalog_titles" | grep -i "$search")
			item_count=$(echo "$results" | wc -l)
			continue
		fi
		if ! [[ "$a" =~ ^[0-9]+$ ]]; then continue; fi
		if [ "$a" -gt "$item_count" -o "$a" -eq 0 ]; then continue; fi

		selection=$(echo "$results" | sed -n "$a"p)
		line_num=$(echo "$catalog_titles" | grep -n "^$selection$" | grep -o '^[0-9]*')
		page=$(echo "$catalog_links" | sed -n "$line_num"p | get - -)
		series_titles=$(get_series_ep_titles "$page")
		series_links=$(get_series_ep_links "$page")
		main "$series_titles" "$series_links" "$selection"
	done
else
	page_count=1
	page=$(get "$base_url/home/latest-episodes/page/$page_count" -)
	latest_titles=$(get_latest_ep_titles "$page")
	latest_links=$(get_latest_ep_links "$page")
	main "$latest_titles" "$latest_links"
fi

