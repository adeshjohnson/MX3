INSERT INTO `dids` (id, did, status, user_id, device_id, subscription_id, reseller_id, closed_till, dialplan_id, language, provider_id, comment, call_limit) 
VALUES ('111', '37063042499', 'active', '5', '7', '0', '0', '2006-01-01 00:00:00', '0', 'en', '1', null, '0');

INSERT INTO `callflows` (id, device_id, cf_type,    priority, action,    data,    data2 )
VALUES (111, 7,       'no_answer ', 1,       'forward', '5i8', 'local');
