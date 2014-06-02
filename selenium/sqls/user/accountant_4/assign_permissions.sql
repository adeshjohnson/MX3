UPDATE `users` SET acc_group_id = 11 WHERE id=4;
UPDATE `users` SET `send_invoice_types` = 0, `recording_hdd_quota` = 0, `recordings_email` = '' WHERE `users`.`id` = 4;
INSERT INTO `actions` (`action`, `data`, `data2`, `data3`, `data4`, `date`, `processed`, `target_id`, `target_type`, `user_id`) VALUES ('user_edited', '', '', NULL, NULL, '2013-10-20 17:37:00', 0, 4, 'user', 0);
UPDATE `users` SET `block_at` = '2013-01-01', `recording_hdd_quota` = 104 WHERE `users`.`id` = 4;
UPDATE `addresses` SET `email` = NULL WHERE `addresses`.`id` = 3;
UPDATE `conflines` SET `value` = 0 WHERE `conflines`.`id` = 330;
