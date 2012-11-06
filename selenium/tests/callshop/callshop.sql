INSERT INTO `groups` (`id`, `name`, `grouptype`, `owner_id`, `description`, `translation_id`) VALUES
(1, 'All users', 'simple', 0, NULL, 1),
(2, 'Test_shop', 'callshop', 0, NULL, 1),
(3, 'reseller_callshop', 'callshop', 3, '', 1),
(4, 'abc', 'callshop', 0, '123', 1),
(5, 'test1', 'callshop', 0, '', 1);

INSERT INTO `usergroups` (`id`, `user_id`, `group_id`, `gusertype`) VALUES 
	 	(1, 0, 1, 'manager'), 
	 	(2, 1, 1, 'user'), 
	 	(3, 2, 1, 'user'), 
	 	(4, 3, 1, 'user');




/* callshop manager and 3 users */

INSERT INTO `users` (`id`, `username`, `             password`, `usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `c2c_service_active`, `temporary_id`, `send_invoice_types`, `call_limit`, `c2c_call_price`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`, `hide_destination_end`, `warning_email_hour`, `warning_balance_call`, `warning_balance_sound_file_id`, `own_providers`, `ignore_global_monitorings`, `currency_id`, `quickforwards_rule_id`, `spy_device_id`, `time_zone`, `minimal_charge`, `minimal_charge_start_at`, `webphone_allow_use`, `webphone_device_id`, `responsible_accountant_id`) VALUES
(6, 'cs_manager', 'e10f43b9351e5d6d48e0bdb4eb7755ad2c617cd8', 'user', 0, 'Callshop manager', '#1', 3.000000000000000, 1, 0.000000000000000, 0.000000000000000, 1, 1, 0, 2, 0.000000000000000, '2000-01-01 00:00:00', 0, 0, 1, 0, -1.000000000000000, NULL, NULL, NULL, NULL, NULL, NULL, 18.000000000000000, NULL, NULL, 0, 0, 0, '2000-01-01 00:00:00', NULL, 0, NULL, 1, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, NULL, 100, 0, 0.000000000000000, 0, 0, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1),
(7, 'cs_user1', '5d604a4d992b49a59bbd184f57cc4264c7727315', 'user', 0, 'Callshop user 1', '#1', 3.000000000000000, 1, 0.000000000000000, 0.000000000000000, 1, 1, 0, 2, 0.000000000000000, '2000-01-01 00:00:00', 0, 0, 1, 0, -1.000000000000000, NULL, NULL, NULL, NULL, NULL, NULL, 18.000000000000000, NULL, NULL, 0, 0, 0, '2000-01-01 00:00:00', NULL, 0, NULL, 1, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, NULL, 100, 0, 0.000000000000000, 0, 0, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1),
(8, 'cs_user2', 'aaaea87dc1bb65c183fcd1a66cbf7d9859707014', 'user', 0, 'Callshop user 2', '#1', 3.000000000000000, 1, 0.000000000000000, 0.000000000000000, 1, 1, 0, 2, 0.000000000000000, '2000-01-01 00:00:00', 0, 0, 1, 0, -1.000000000000000, NULL, NULL, NULL, NULL, NULL, NULL, 18.000000000000000, NULL, NULL, 0, 0, 0, '2000-01-01 00:00:00', NULL, 0, NULL, 1, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, NULL, 100, 0, 0.000000000000000, 0, 0, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1),
(9, 'cs_user3', '6a0f10e870f1b4d43515aa64ae2467a6db260f54', 'user', 0, 'Callshop user 3', '#1', 3.000000000000000, 1, 0.000000000000000, 0.000000000000000, 1, 1, 0, 2, 0.000000000000000, '2000-01-01 00:00:00', 0, 0, 1, 0, -1.000000000000000, NULL, NULL, NULL, NULL, NULL, NULL, 18.000000000000000, NULL, NULL, 0, 0, 0, '2000-01-01 00:00:00', NULL, 0, NULL, 1, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, NULL, 100, 0, 0.000000000000000, 0, 0, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1),
(10, 'reseller_booth', '44e217747ba89e28c423e020ccc761be2244a8cc', 'user', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 1, 1, 1, 3, 0.000000000000000, NULL, 0, 0, 1, 0, -1.000000000000000, '', '0000000004', '2012-10-29', '', 123, '', 0.000000000000000, 9, '', 3, 0, 0, '2000-01-01 00:00:00', '5w17x2ay88', 0, NULL, 0, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, NULL, 0, 0, 0.000000000000000, 0, 8, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1),
(11, 'cs_user_extra', '03d8df9823a8112a0ec9bda27bce039f2766ff6f', 'user', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 1, 1, 0, 2, 0.000000000000000, NULL, 0, 0, 1, 0, -1.000000000000000, '', '0000000005', '2012-10-29', '', 123, '', 0.000000000000000, 10, '', 0, 0, 0, '2000-01-01 00:00:00', '2g1ptq002w', 0, NULL, 0, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 11, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1);


Update users set time_zone = 'UTC';
/* devices for cs_users */

INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`) VALUES 
(11,'110','dynamic','110','mor_local','0.0.0.0',0,1175892667,2,'\"110\" <110>','110',0,'110','IAX2',7,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for cs_user 1',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
(12,'111','dynamic','110','mor_local','0.0.0.0',0,1175892667,2,'\"111\" <111>','111',0,'110','IAX2',8,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for cs_user 2',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
(13,'112','dynamic','112','mor_local','0.0.0.0',0,1175892667,2,'\"112\" <112>','112',0,'110','IAX2',9,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for cs_user 3',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL);
