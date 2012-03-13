delete locationrules.* from locationrules where location_id in (select id from locations where user_id = 3);
delete locations.* from locations where user_id = 3;
delete conflines.* from conflines where owner_id = 3 and  name = 'Default_device_location_id';
