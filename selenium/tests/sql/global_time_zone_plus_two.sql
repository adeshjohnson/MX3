SET GLOBAL time_zone='+02:00';
update conflines set value=2 where name = 'System_time_zone_ofset';
