#!/bin/bash

for file in "$@"
do
    dest="${file%.*}-utf8.srt"
    backup="${file}.orig"
    cp "$file" "$backup"
    iconv --from-code=ISO-8859-7 --to-code=UTF-8 "$file" > "$dest"
    mv "$dest" "$file"
done
