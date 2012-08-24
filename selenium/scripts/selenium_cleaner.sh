#! /bin/bash 
 
      
 
selenium_clean()
{
    if [ -f "/tmp/.mor_test_is_running" ]; then
        echo "Selenium tests are running. Start clean later..."
        exit 1;
    else
        touch /tmp/.mor_test_is_running
    fi

    echo "Stopping Selenium"
    killall java
    rm -rf /usr/local/mor/backups/db_dump_* /var/log/mor/* /tmp/ruby_sess.* /tmp/CGI.* /tmp/_sox.txt*
    chmod +x /usr/bin/mor /home/mor/selenium/scripts/mor_test_run.sh /bin/mor &2> /dev/null
    mor -s

    rm -rf /tmp/.mor_test_is_running
}

selenium_clean
