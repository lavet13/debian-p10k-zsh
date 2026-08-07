#!/usr/bin/env bash
# Copy a file to the clipboard as text/uri-list (so GUI apps paste it AS A FILE).
# Percent-encodes the path — spaces / & / [ ] / @ in a raw file:// URI resolve to the
# wrong path (Telegram: "is empty and can't be sent"). safe="/" keeps the slashes.
path=$1
enc=$(python3 -c 'import sys,urllib.parse as u; print(u.quote(sys.argv[1], safe="/"))' "$path")
printf 'file://%s' "$enc" | wl-copy -t text/uri-list
