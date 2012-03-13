#set global time_zone='-10:00';
update conflines set value=-10 where name = 'System_time_zone_ofset';
