UPDATE `devices` SET `description` = 'res_prov_iax2', `user_id` = 5, `server_id` = 4302, `auth` = 'md5' WHERE `devices`.`id` = 2304;
UPDATE devices SET accountcode = id WHERE id = 2304;
INSERT IGNORE INTO voicemail_boxes (device_id, mailbox, password, fullname, context, email, pager, dialout, callback) VALUES ('2304', 'wderymp0yg', '', 'User Resellers', 'default', '', '', '', '');
INSERT INTO `server_devices` (`device_id`, `server_id`) VALUES (2304, 4302);