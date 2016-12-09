#!/bin/bash
tmp=$(sensors k10temp-pci-00c3 | grep "temp1" | grep "+[0-9]*.[0-9]" -o | head -n 1)
echo ${tmp:1}
