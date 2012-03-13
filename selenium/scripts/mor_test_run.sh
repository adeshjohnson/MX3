
#! /bin/bash
#===== README ====
# MOR installation must be upgraded to the most recent version
# This script upgrades mor GUI only with a command specified by GUI_UPGRADE_CMD  variable
# selenium-server must be running
# start selenium server with command:
# 		./mor_test_run.sh -s
#
#==============
#============SETTINGS========================

MODE=0; # 0 - mode for a local testing system (doesn't send email to all recipients, only the person who is testing, doesn't upgrade gui with tests). 1 - mode for a real test server

TESTER_EMAIL=""; #tests tester


FIRST_GLOBAL_PARAM=$1;
SECOND_GLOBAL_PARAM=$2;

MOR_VERSION_YOU_ARE_TESTING=`cat /home/mor/.svn/entries | grep http | awk -F"/" '{
  if($6 == "trunk")
    print $6;
  else
    print $7;
}'`


PATH_TO_DATABASE_SQL=/home/mor/selenium/mor_"$MOR_VERSION_YOU_ARE_TESTING"_testdb.sql;
LOGFILE_NAME="mor_test_ataskaita";
DIR_FOR_LOG_FILES="/usr/local/mor/test_environment/reports"; #must end without slash ("/")
SEND_EMAIL="/usr/local/mor/sendEmail"
GUI_UPGRADE_CMD="/home/mor/gui_upgrade_light.sh"
DIR_TO_STORE_DATABASE_DUMPS="/usr/local/mor/test_environment/dumps"
TEST_DIR="/home/mor/selenium/tests"
LAST_REVISION_FILE="/usr/local/mor/test_environment/last_revision"; #here we will track completed tests
TEST_RUNNING_LOCK="/tmp/.mor_test_is_running";
MOR_CRASH_LOG="/tmp/mor_crash.log"
SELENIUM_SERVER_LOG="/var/log/mor/selenium_server.log"

BETA_TESTS_DIR="/home/mor/selenium/beta_tests"
TEST_BETA_TESTS=50; #how many times beta test will be run

if [ "$MODE" == "0" ]; then
	E_MAIL_RECIPIENTS="$TESTER_EMAIL" #separate each address with a space
elif [ "$MODE" == "1" ]; then
	E_MAIL_RECIPIENTS="info@kolmisoft.com m.mardosas@gmail.com martynas.margis@gmail.com tankiaitaskuota@gmail.com" #separate each address with a space
else
	echo "Unknown error when selecting MODE"
fi


#=======OPTIONS========
: ${dbg:="1"}	# dbg= {0 - off, 1 - on }  for debuging purposes
#============FUNCTIONS====================
change_email_in_environment_rb()
{
    #   Author: Mindaugas Mardosas
    #   Year:   2011
    #   About:  This function replaces default reporting mail

    sed 's/guicrashes@kolmisoft.com\|support@kolmisoft.com/kolmisoft.mindaugas.crm@gmail.com/g'  /home/mor/config/environment.rb > /home/mor/config/environment.rb2
    mv /home/mor/config/environment.rb2 /home/mor/config/environment.rb
}
#------------------------------------------
mysql_total_tables()
{
  NUM_OF_TABLES=`mysql mor -e "show tables" | (read; grep "[a-z]" ) | wc -l`
  echo -e "Total number of MySQL tables:\t\t\t$NUM_OF_TABLES"
}
#-------------------------
import_db(){

  cd /usr/src/mor/db/0.8/
  ./make_new_db.sh nobk

  if [ "$SECOND_GLOBAL_PARAM" == "" ]; then
    SECOND_GLOBAL_PARAM="$MOR_VERSION_YOU_ARE_TESTING"
  fi


  if [ "$SECOND_GLOBAL_PARAM" == "8" ]; then    # if we want specific version (mor -l 8)
    echo "Changing MOR version to 8";
    PATH_TO_DATABASE_SQL=/home/mor/selenium/mor_0.8_testdb.sql;
    mysql mor < $PATH_TO_DATABASE_SQL;

  elif [ "$SECOND_GLOBAL_PARAM" == "9" ]; then  # if we want specific version (mor -l 9)
    echo "Changing MOR version to 9";

    mysql mor < /home/mor/selenium/mor_0.8_testdb.sql;
    /usr/src/mor/db/9/import_changes.sh
    mysql mor < /home/mor/selenium/mor_9_testdb.sql

  elif [ "$SECOND_GLOBAL_PARAM" == "10" ]; then    #updating current version
    echo "Changing MOR version to 10";
    mysql mor < /home/mor/selenium/mor_0.8_testdb.sql;
    /usr/src/mor/db/9/import_changes.sh
    #mysql mor < /home/mor/selenium/mor_9_testdb.sql
    /usr/src/mor/db/10/import_changes.sh
    mysql mor < /home/mor/selenium/mor_trunk_testdb.sql

  elif [ "$MOR_VERSION_YOU_ARE_TESTING" == "trunk" ] || [ "$MOR_VERSION_YOU_ARE_TESTING" == "11" ] || [ "$SECOND_GLOBAL_PARAM" == "11" ]; then    #updating current version
    mysql mor < /home/mor/selenium/mor_0.8_testdb.sql;
    /usr/src/mor/db/9/import_changes.sh
    #mysql mor < /home/mor/selenium/mor_9_testdb.sql
    /usr/src/mor/db/10/import_changes.sh
   /usr/src/mor/db/trunk/import_changes.sh
    mysql mor < /home/mor/selenium/mor_trunk_testdb.sql

  elif [ "$MOR_VERSION_YOU_ARE_TESTING" == "8" ]; then        #updating current version
    PATH_TO_DATABASE_SQL=/home/mor/selenium/mor_0.8_testdb.sql;
    mysql mor < $PATH_TO_DATABASE_SQL;

  elif [ "$MOR_VERSION_YOU_ARE_TESTING" == "9" ]; then        #updating current version
    mysql mor < /home/mor/selenium/mor_0.8_testdb.sql;
    /usr/src/mor/db/9/import_changes.sh
    mysql mor < /home/mor/selenium/mor_9_testdb.sql
  fi



}
#------------------------------------------
dir_exists()
{
   if [ -d "$1" ];
			then
					[ $dbg == 1 ] && echo "$1 is dir";
					return 0;
      else return 1;
   fi
}
#-------------------------------------------
_mor_time()
{
	mor_time=`date +%Y\-%0m\-%0d\_%0k\:%0M\:%0S`;
}
#--------------------------------------------
run_all_rb()
{
		echo "1 paduotas kint: $1"
		delete_all_rb;
		convert_html_cases_to_rb "$1";

		echo -e "REVISION: $CURRENT_REVISION\nLAST AUTHOR: $LAST_AUTHOR">>$report

		find $TEST_DIR -name "*.rb" | sort | while read testas
		do
			dir_exists testas; #checking whether we have path to dir or file
			if [ $? == 0 ]; then continue; fi; #let's do another cicle, nothing to do with dir..'

			import_db; #dropping and importing a fresh database

			echo "Proceeding test: $testas"
			ruby -rubygems $testas  >> $report  #logging the report to file   #| egrep "failures|Loaded"
			echo -e "\n----\n" >> $report;
		done

		echo -e "Report was generated...\nReport was saved to $report\n";
}
#=====================
delete_all_rb()
{
	echo "Deleting stale *.rb files";
		find $TEST_DIR -name "*.rb" | sort | while read testas
		do
			dir_exists testas; #checking whether we have path to dir or file
			if [ $? == 0 ]; then continue; fi; #let's do another cicle, nothing to do with dir..'

			rm -rf $testas
		done
		echo "All stale *rb files were deleted";
}
#=====================================================================
last_directory_in_the_path()
{
	last_dir_in_path=`pwd | awk -F\/ '{print $(NF)}'`;
}
#===========================MAIL======================================
send_report_by_email()	{
	if [ -f "$SEND_EMAIL" ]; then

		if [ "$STATUS" == "OK" ]; then
			$SEND_EMAIL -f mor_tests@kolmisoft.com -t $E_MAIL_RECIPIENTS -u "[$STATUS][MOR TESTS C1 $MOR_VERSION_YOU_ARE_TESTING] $CURRENT_REVISION $mor_time" -m "REVISION: $CURRENT_REVISION  LAST AUTHOR: $LAST_AUTHOR  STATUS: $STATUS     `cat $report`"  -o reply-to=mor_tests@kolmisoft.com tls=auto -s smtp.gmail.com -xu kolmitest -xp kolmitest99 > /tmp/mor_temp

		elif [ "$STATUS" == "FAILED" ]; then
			$SEND_EMAIL -f mor_tests@kolmisoft.com -t $E_MAIL_RECIPIENTS -u "[$STATUS][MOR TESTS C1 $MOR_VERSION_YOU_ARE_TESTING] $CURRENT_REVISION $mor_time" -m "REVISION: $CURRENT_REVISION  LAST AUTHOR: $LAST_AUTHOR  STATUS: $STATUS `cat $report`" -a $MOR_CRASH_LOG -o reply-to=mor_tests@kolmisoft.com tls=auto -s smtp.gmail.com -xu kolmitest -xp kolmitest99 > /tmp/mor_temp
		fi

		else echo "$SEND_EMAIL NOT FOUND!";
	fi
	if [ $? == 0 ]; then echo "Email was sent"; fi
}
#=====================================================================
convert_html_cases_to_rb()
{
	find $TEST_DIR -name "*.case" | sort | while read testas
		do
			dir_exists testas; #checking whether we have path to dir or file
			if [ $? == 0 ]; then continue; fi; #let's do another cicle, nothing to do with dir..'
			echo "Converting test: $testas"
			ruby /home/mor/selenium/converter/converter.rb -h "http://$1" $testas >> $report
		done
		test_if_all_tests_were_converted_successfully
}
#====================================================================
is_another_test_still_running()
{
	if [ -f "$TEST_RUNNING_LOCK" ]; then
		echo "$mor_time Another test is already running, exiting";
		exit 0;
	fi
}
#======================================
test_if_all_tests_were_converted_successfully(){
	RB_FILES=`find $TEST_DIR -name "*.rb" | wc -l`;
	CASE_FILES=`find $TEST_DIR -name "*.case" | wc -l`;

	if [ $RB_FILES -ne $CASE_FILES ];
		then
			echo "Converting tests failed, stopping the script";
			$SEND_EMAIL -f mor_tests@kolmisoft.com -t $E_MAIL_RECIPIENTS -u "[FAILED][MOR TESTS $MOR_VERSION_YOU_ARE_TESTING] $mor_time" -m "REVISION: $CURRENT_REVISION  LAST AUTHOR: $LAST_AUTHOR  STATUS: FAILED TO CONVERT THE TESTS" -o reply-to=mor_tests@kolmisoft.com tls=auto -s smtp.gmail.com -xu kolmitest -xp kolmitest99 > /tmp/mor_temp
			rm -rf "$TEST_RUNNING_LOCK"
			exit 1;
		else
			echo "Successfully converted the tests";
	fi
}

test_beta_tests(){
	rm -rf $BETA_TESTS_DIR/*.rb
	find $BETA_TESTS_DIR -name "*.case" | sort | while read testas
		do
				echo "Converting beta test: $testas"
				ruby /home/mor/selenium/converter/converter.rb -h "http://localhost" $testas
		done

	find $BETA_TESTS_DIR -name "*.rb" | sort | while read testas
		do
			if [ ! -f "$testas"_report ]; then
				> /tmp/selenium_debugas

				for i in $(seq 1 $TEST_BETA_TESTS)
					do
						echo "Launching test: $i"
						echo "Importing the database" >> /tmp/selenium_debugas;
						/usr/local/mor/test_environment/mor_test_run.sh -i
						echo "Launched the ruby test" >> /tmp/selenium_debugas;
						ruby "$testas" >> /tmp/selenium_debugas;

						#====checking for errors or failures
						grep "Error:" /tmp/selenium_debugas
						if [ "$?" == "0" ]; then
							STATUS="FAILED";
							break;  #exiting the loop, because an error was found
							else STATUS="OK";
						fi

						grep "Failure:" $report
						if [ "$?" == "0" ]; then
							STATUS="FAILED";
							break;  #exiting the loop, because an error was found
						fi
						#===================================
				done

				echo $STATUS >> /tmp/selenium_debugas
				echo $STATUS;
				cp /tmp/selenium_debugas "$testas"_report
			fi
		done
}


#====================================MAIN============================
_mor_time;


touch /var/log/mor/monitorings.log
chmod 777 /var/log/mor/monitorings.log


if [ -z "$1" ];
	then
		echo -e "\n\n=========MOR TEST ENGINE CONTROLLER=======";
		echo "Arguments:";
		echo -e "\t-a \tUpgrades GUI, resets a database, runs all tests, sends the report by email.";
		#echo -e "\t-i \tGives you a fresh database, by importing $PATH_TO_DATABASE_SQL";
		echo -e "\t-d \tReload the database; Example: -d - reloads current DB; -d 8 -reloads 8 DB; -d 9 - reloads 9 DB";
		echo -e "\t-h \tRestart the HTTPd";
		#echo -e "\t-r \tNOT USED ANYMORE - Dumps a current database state to $DIR_TO_STORE_DATABASE_DUMPS and replaces the default database file $PATH_TO_DATABASE_SQL \n";
		echo -e "\t-s \tStart a Selenium RC server\n";
		echo -e "\t-l \tNEW GUI, NEW TEST DB\n";
		echo -e "\t-b \tRuns beta tests\n";
        echo -e "\t-rm \tRemove lock\n";

	elif [ "$1" == "-a" ]; then  #do all tasks

				URL="$2" #saving second parameter before it gets overwritten by set command

				is_another_test_still_running #if another instance is running - script will terminate.

				touch "$TEST_RUNNING_LOCK"  #creating the lock

				svn co http://svn.kolmisoft.com/mor/install_script/trunk/ /usr/src/mor
				chmod +x /usr/bin/mor
				chmod +x /home/mor/selenium/scripts/mor_test_run.sh

				rm -rf /tmp/mor_crash.log
				echo -e "\n------\n" >> /var/log/mor/selenium_server.log
				touch /tmp/mor_crash.log
				chmod 777 /tmp/mor_crash.log

				[ $dbg == 1 ] && echo -e "\n$mor_time";

				if [ "$MODE" == "1" ]; then	$GUI_UPGRADE_CMD; fi #upgrading GUI



				set $(cd /home/mor/ && svn info | grep "Last Changed Rev") &> /dev/null
				CURRENT_REVISION="$4";  #newest

				set $(cat "$LAST_REVISION_FILE" | tail -n 1 ) &> /dev/null

				LAST_REVISION=$2;

				set $(cd /home/mor/ && svn info | grep "Last Changed Author:");
				LAST_AUTHOR="$4"

				[ $dbg == 1 ] && echo "Current revision: $CURRENT_REVISION";
				[ $dbg == 1 ] && echo "Last revision: $LAST_REVISION";
				[ $dbg == 1 ] && echo "Last author: $LAST_AUTHOR";


				if [ "$CURRENT_REVISION" != "$LAST_REVISION" ] || [ "$MODE" == "0" ]; then
						[ $dbg == 1 ] && echo "Versions didn't matched, running the tests"
						/etc/init.d/httpd restart
						report="$DIR_FOR_LOG_FILES/$LOGFILE_NAME.$mor_time.txt"
						run_all_rb "$URL";

												#	killall firefox  #this is needed because we started to use selenium server option "-browserSessionReuse", so selenium now doesn't kill the browser.

						#====checking for errors or failures
						grep "Error:" $report
						if [ "$?" == "0" ]; then
							STATUS="FAILED";
							else STATUS="OK";
						fi

						grep "Failure:" $report
						if [ "$?" == "0" ]; then STATUS="FAILED"; fi
						#===================================

						[ $dbg == 1 ] && echo  "$STATUS";
						send_report_by_email;
						echo -e "$mor_time\t$CURRENT_REVISION\t\t$LAST_AUTHOR\t$STATUS" >> $LAST_REVISION_FILE
				fi

				rm -rf "$TEST_RUNNING_LOCK";
				if [ "$?" != "0" ]; then echo "$mor_time Failed to delete $TEST_RUNNING_LOCK lock"; fi;

	elif [ "$1" == "-l" ]; then
        /etc/init.d/httpd stop
        rm -rf /home/mor/app /usr/local/mor/backups/GUI/*

    if [ "$SECOND_GLOBAL_PARAM" == "8" ]; then
        svn co http://svn.kolmisoft.com/mor/install_script/trunk/ /usr/src/mor &
        /usr/src/mor/upgrade/0.8/gui_upgrade.sh
    elif [ "$SECOND_GLOBAL_PARAM" == "9" ]; then
        /usr/src/mor/upgrade/9/fix.sh
    elif [ "$SECOND_GLOBAL_PARAM" == "10" ]; then
        /usr/src/mor/upgrade/10/fix.sh
    elif [ "$SECOND_GLOBAL_PARAM" == "11" ]; then
        /usr/src/mor/upgrade/trunk/fix_trunk.sh
    else
        svn co http://svn.kolmisoft.com/mor/install_script/trunk/ /usr/src/mor &
        if [ "$MOR_VERSION_YOU_ARE_TESTING" == "trunk" ]; then
            svn co http://svn.kolmisoft.com/mor/gui/trunk/ /home/mor
        else
            svn co http://svn.kolmisoft.com/mor/gui/branches/$MOR_VERSION_YOU_ARE_TESTING /home/mor
        fi
    fi

        chmod 777 /home/mor/public/images/logo/ &

		import_db; 	#import
		chmod +x /usr/bin/mor
		chmod +x /home/mor/selenium/scripts/mor_test_run.sh
        change_email_in_environment_rb
        /etc/init.d/httpd start
        mysql_total_tables

	elif [ "$1" == "-d" ]; then
       import_db

    elif [ "$1" == "-rm" ]; then
        rm -rf $TEST_RUNNING_LOCK
        if [ "$?" == "0" ]; then
            echo "The lock was deleted"
        fi

    elif [ "$1" == "-h" ]; then
       /etc/init.d/httpd  restart
	elif [ "$1" == "-b" ]; then   #RUN BETA TESTS
				is_another_test_still_running #if another instance is running - script will terminate.
				touch "$TEST_RUNNING_LOCK"  #creating the lock
				test_beta_tests;
				rm -rf "$TEST_RUNNING_LOCK";
				if [ "$?" != "0" ]; then echo "$mor_time Failed to delete $TEST_RUNNING_LOCK lock"; fi;
	elif [ "$1" == "-s" ]; then
			echo "Starting a Selenium RC server";

								#outdated
								# 2009.05.16 DISPLAY=:0 /usr/local/mor/test_environment/jre1.6.0_13/bin/java -jar /usr/local/mor/test_environment/selenium-server.jar -singleWindow >> /var/log/mor/selenium_server.log &
			DISPLAY=:0 /usr/local/mor/test_environment/jre1.6.0_13/bin/java -jar /usr/local/mor/test_environment/selenium-server.jar -singleWindow >> /var/log/mor/selenium_server.log &
fi


