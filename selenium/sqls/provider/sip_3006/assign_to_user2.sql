UPDATE `devices` SET `description` = 'admin_prov_sip', `user_id` = 2, `server_id` = 4302 WHERE `devices`.`id` = 2005;
UPDATE devices SET accountcode = id WHERE id = 2005;
INSERT IGNORE INTO voicemail_boxes (device_id, mailbox, password, fullname, context, email, pager, dialout, callback) VALUES ('2005', 'c3ed8hur1b', '', 'Test User #1', 'default', '', '', '', '');
INSERT INTO `server_devices` (`device_id`, `server_id`) VALUES (2005, 4001);
INSERT INTO `server_devices` (`device_id`, `server_id`) VALUES (2005, 4302);