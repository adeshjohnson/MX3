UPDATE conflines SET value='900000' WHERE name='Hide_active_calls_longer_than';
update activecalls set start_time=NOW() where start_time='0000-00-00 00:00:00';
