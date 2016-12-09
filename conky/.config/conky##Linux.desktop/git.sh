#!/bin/bash
curDir=$(pwd)
colDef='${color 657b83}'
colHi='${color 2aa198}'
colName='${color 6c71c4}'
colNew='${color 859900}'
colMod='${color b58900}'
colDel='${color dc322f}'
cd $1
cleanStatus=$(git status | grep "working tree clean" | wc -l)
if [ $cleanStatus == "1" ]
then
  clean=$colNew"yes"
else
  clean=$colMod"no"
fi
newFiles=$(git status | grep "new file:" | wc -l)
modified=$(git status | grep "modified:" | wc -l)
deleted=$(git status | grep "deleted:" | wc -l)
lastCommit=$(git log -1 --format=%cd --date=relative)
echo $colName$1$colDef
echo "clean: new: modified: deleted: last commit:"
echo "$clean\${goto 60}$colNew$newFiles\${goto 100}$colMod$modified\${goto 180}$colDel$deleted\${goto 255}$colHi$lastCommit $colDef"
cd $curDir
