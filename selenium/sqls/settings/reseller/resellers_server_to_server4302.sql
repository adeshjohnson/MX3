# reseller device
UPDATE devices SET server_id = 4302 WHERE id = 6;
INSERT INTO `server_devices` (`device_id`, `server_id`) VALUES (6, 4302);
DELETE FROM server_devices WHERE device_id = '6' AND server_id NOT IN (4302);
# reseller user device
UPDATE devices SET server_id = 4302 WHERE id = 7;
INSERT INTO `server_devices` (`device_id`, `server_id`) VALUES (7, 4302);
DELETE FROM server_devices WHERE device_id = '7' AND server_id NOT IN (4302);
# action
INSERT INTO `actions` (`action`, `data`, `data2`, `data3`, `data4`, `date`, `processed`, `target_id`, `target_type`, `user_id`) VALUES ('Confline changed', '1', '4302', NULL, 'Resellers_server_id', '2013-10-11 18:43:57', 0, 278, 'confline', 0);
# confline
UPDATE `conflines` SET `value` = 4302 WHERE `conflines`.`id` = 278;
