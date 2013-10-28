UPDATE `devices` SET `description` = 'Test Provider', `user_id` = 2, `language` = 'en', `subscribemwi` = 'no' WHERE `devices`.`id` = 1;
UPDATE devices SET accountcode = id WHERE id = 1;
INSERT IGNORE INTO voicemail_boxes (device_id, mailbox, password, fullname, context, email, pager, dialout, callback) VALUES ('1', 'prov_test', '', 'Test User #1', 'default', '', '', '', '');
INSERT INTO `server_devices` (`device_id`, `server_id`) VALUES (1, 4001);
INSERT INTO `server_devices` (`device_id`, `server_id`) VALUES (1, 4302);