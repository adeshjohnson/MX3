#! /bin/bash
	report="/tmp/selenium_debugas";
	TEST_RUNNING_LOCK="/tmp/.mor_test_is_running";

 
if [ -n "$1" -a -n "$2" ]; then
	#===========
	if [ "$1" == "-r" ]; then
		> /tmp/selenium_debugas
		if [ "$?" == "0" ]; then
			echo "/tmp/selenium_debugas was cleaned"

		fi
		exit 0;
	fi

	if [  "$2" == "-c" ]; then
		ruby /home/mor/selenium/converter/converter.rb -h "http://127.0.0.1" "$1"
		exit 0;
	fi
	#============	
	if [ ! -f "$TEST_RUNNING_LOCK" ]; 
		then touch "$TEST_RUNNING_LOCK";
		else 
			echo "Another test is running. If you are sure, that no tests are running - delete file lock $TEST_RUNNING_LOCK";
			exit 1;
	fi
		
		> $report

	for i in $(seq 1 $2)
		do			
			echo "Launching test: $i"
			echo "Importing the database" >> $report;
			sh /home/mor/selenium/scripts/mor_test_run.sh -l
			echo "Launched the ruby test" >> $report;
			ruby "$1" >> /tmp/selenium_debugas;

			#====checking for errors or failures
			grep "Error:" $report
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

	rm -rf "$TEST_RUNNING_LOCK";



	echo  "$STATUS";

	else echo -e "Possible usage:\n./selenium_debugger.sh testas.rb how_many_times\t\t#how many times to run the test\n./selenium_debugger.sh test.case -c \t\t\t#converts the case file to ruby\n./selenium_debugger.sh -r anything\t\t\t\t#cleans the /tmp/selenium_debugas";
fi
