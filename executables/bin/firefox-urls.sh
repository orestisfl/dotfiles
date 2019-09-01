#!/bin/bash

firefox -new-window
sleep 0.1
while read URL; do
    firefox "$URL"
done < "$1"
