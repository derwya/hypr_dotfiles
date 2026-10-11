#!/bin/bash
# Web search (SUPER+U). Prefixes: "yt " YouTube, "gh " GitHub, "aur " AUR,
# "aw " Arch Wiki; anything else goes to Google. The query is URL-encoded.

query=$(rofi -dmenu -p "󰖟  Search" -mesg "yt · gh · aur · aw prefixes, or just type" </dev/null)
[[ -n $query ]] || exit 0

case "$query" in
  "yt "*)  base="https://www.youtube.com/results?search_query=";  query=${query#yt } ;;
  "gh "*)  base="https://github.com/search?q=";                     query=${query#gh } ;;
  "aur "*) base="https://aur.archlinux.org/packages?K=";            query=${query#aur } ;;
  "aw "*)  base="https://wiki.archlinux.org/index.php?search=";     query=${query#aw } ;;
  *)       base="https://www.google.com/search?q=" ;;
esac

xdg-open "${base}$(jq -rn --arg q "$query" '$q | @uri')"
