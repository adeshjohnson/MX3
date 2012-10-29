delete locationrules.* from locationrules where location_id in (select id from locations where user_id in (3,10,11,12,13));
delete locations.* from locations where user_id  in (3,10,11,12,13);
delete conflines.* from conflines where owner_id in (3,10,11,12,13) and  name = 'Default_device_location_id';
