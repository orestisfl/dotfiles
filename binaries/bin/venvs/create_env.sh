#!/bin/bash
set -e
pycmd=python$pyver
pipcmd=pip$pyver
packages="${packages:-ipython[all]}"
targetdir="${targetdir:-new_env}"
use_site_packages="${use_site_packages:-false}"
if [ "$use_site_packages" = true ] ; then
    site_packages_flag=--system-site-packages
else
    site_packages_flag=--no-site-packages
fi

if [ -d "$targetdir" ]; then
    # $targetdir exists.
    echo "targetdir: $targetdir already exists"
    exit 1;
fi

# create new env
virtualenv $site_packages_flag -p $pycmd $targetdir

# activate the env
source $targetdir/bin/activate

# https://gist.github.com/jlesquembre/2042882 to get pyqt so qtconsole can be used.
# link pyqt
~/bin/venvs/postmkvirtualenv.sh

# install packages
for package in $packages
do
    $pipcmd install $package
done
exit
