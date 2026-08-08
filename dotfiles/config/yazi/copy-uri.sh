#!/usr/bin/env bash
# Copy one OR MANY files to the clipboard as text/uri-list, so GUI apps paste them
# AS FILES. Percent-encodes each path (spaces / & / [ ] resolve wrong otherwise).
# yazi passes selected files as separate args → loop over "$@".

out=""
for path in "$@"; do
  # urllib.parse.quote with safe="/" keeps the path slashes, encodes everything else
  enc=$(python3 -c 'import sys,urllib.parse as u; print(u.quote(sys.argv[1], safe="/"))' "$path")
  out+="file://$enc"$'\n'      # one file:// URI per line — the uri-list format
done
printf '%s' "$out" | wl-copy -t text/uri-list
