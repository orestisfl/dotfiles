#!/bin/bash

n_screens=$(xrandr | grep '*' | wc -l)
if [ $n_screens -eq 1 ]
then
    ~/.screenlayout/1920-1080-radeon-dual.sh
else
    ~/.screenlayout/1920-1080-radeon-single.sh
fi
