#!/bin/bash
# Author:	Mindaugas Mardosas
# Year:		2013
# About:	This script loads single SQL file. This feature works similar to one described here: http://doc.kolmisoft.com/display/kolmisoft/Bundle+SQL

FILE="$1"

mysql -u mor -pmor mor < "/home/mor/selenium/sqls/$FILE" 2>&1
if [ "$?" == "0" ]; then
	echo "[OK] /home/mor/selenium/sqls/$FILE imported"
else
	echo "[FAILED] Failed to import /home/mor/selenium/sqls/$FILE"
	exit 1
fi
