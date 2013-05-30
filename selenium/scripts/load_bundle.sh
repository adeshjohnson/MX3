#!/bin/bash

FILE=$1
exec < $FILE
while read LINE
do
    if [ ${LINE:0:1} = '#' ]
    then
	# comment
	echo $LINE
	echo "<br>"
    else
	mysql -u mor -pmor mor < "/home/mor/selenium/sqls/$LINE" 2>&1
	if [ "$?" != "0" ]; then
	    echo "<br>Failed to load this SQL file: /home/mor/selenium/sqls/$LINE"
	    echo "<br>----<br>"
	    echo `cat /home/mor/selenium/sqls/$LINE`
	    exit 1;
	fi 
    fi

done
