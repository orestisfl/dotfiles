#!/bin/bash
# name1=$(lspci -nnk | grep -i vga)
name1="HD 7850"
temp1=$(sensors radeon-pci-0100 | grep "temp1" | grep "+[0-9]*.[0-9]" -o | head -n 1)
fan1=$(expr $(cat /sys/class/drm/card0/device/hwmon/hwmon2/pwm1)00 / 255)
echo "$name1\${alignr 30}$temp1°C\${offset 30}$fan1%" | column -t
