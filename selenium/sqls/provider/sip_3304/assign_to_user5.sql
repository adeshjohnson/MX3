UPDATE `devices` SET `description` = 'res_prov_sip', `user_id` = 5, `server_id` = 4302 WHERE `devices`.`id` = 2303;
UPDATE devices SET accountcode = id WHERE id = 2303;
INSERT IGNORE INTO voicemail_boxes (device_id, mailbox, password, fullname, context, email, pager, dialout, callback) VALUES ('2303', '6qpm5wp7jw', '', 'User Resellers', 'default', '', '', '', '');
INSERT INTO `server_devices` (`device_id`, `server_id`) VALUES (2303, 4302);