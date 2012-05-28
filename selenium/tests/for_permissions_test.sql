INSERT INTO `acc_groups`(`id`,`name`) VALUES (1,'Accountant_Permissions');   
INSERT INTO `backups`   (`id`,`backuptime`,`comment`,`backuptype`) VALUES (1 ,'20110929151451','Komentaras','manual');
INSERT INTO `providerrules` (`id`,`provider_id`,`name`,`enabled`,`cut`,`add`,`minlen`,`maxlen`,`pr_type`) VALUES (1,1,'name',1,'86','370',1,100,'dst');
INSERT INTO `terminators` (`id`,`name`) VALUES (1,'terminator');
INSERT INTO `dialplans` (`id`,`name`,`dptype`,`data1`,`data2`,`data3`,`data4`,`data5`,`data6`,`data7`,`data8`) VALUES
(  2 ,'CC_DILAPLAN'          ,'callingcard'  , 10   , 4     , 1     , 1     , 3     , 3     , 1     , 1     ),
(  3 ,'AUTH_BY_PIN_DIALPLAN' ,'authbypin'    , 3    , 3     , 1     , NULL  , NULL  , NULL  , NULL  , NULL  ),
(  4 ,'IVRS_DIALPLAN'        ,'ivr'          ,''    ,''     ,''     ,''     ,''     ,''     ,''     , NULL  ),
(  5 ,'CALLBACK_DIALPLAN'    ,'callback'     , 1    , 5     , 4     , NULL  , NULL  , NULL  , NULL  , NULL  ),
(  6 ,'PBXFUNCTION'          ,'pbxfunction'  , 6    , 234   , NULL  , NULL  , NULL  , NULL  , NULL  , NULL  );
INSERT INTO `phonebooks`(`id`,`user_id`,`number`     ,`name`,`added`              ,`card_id`,`speeddial`,`updated_at`) VALUES (  1 ,       0 ,'37060064753','JON' ,'2011-10-01 09:31:23',       0 , '876'     ,'2011-10-01 09:31:23');
INSERT INTO `ivr_voices`(`id`,`voice`    ,`description`,`created_at`) VALUES (  111 ,'VOICEname','Description','2011-10-01 09:37:35');
INSERT INTO `ivr_timeperiods`(`id`,`name`       ,`start_hour`,`end_hour`,`start_minute`,`end_minute`,`start_weekday`,`end_weekday`,`start_day`,`end_day`,`start_month`,`end_month`) VALUES ( 1  ,'TIMEPERIOD' ,        '0' ,     '23' ,          '0' ,       '59' ,'thu'          ,'thu'        ,        '5',      '5',          '5',       '9'); 
INSERT INTO `ivrs` (`id`,`name`,`start_block_id`) VALUES (1 ,'IVRs',1);
INSERT INTO `locations`(`id`,`name`) VALUES (2,'Location');
INSERT INTO `subscriptions`(`id`,`service_id`,`user_id`,`device_id`) VALUES ( 2,1,0,1);
INSERT INTO `invoices`(`id`,`user_id`,`period_start`,`period_end`,`issue_date`,`paid`,`paid_date`,`price`,`price_with_vat`,`payment_id`,`number`,`sent_email`,`sent_manually`,`invoice_type`,`number_type`,`tax_id`) VALUES  (  1 ,      2  ,'2011-10-01'  ,'2011-10-01','2011-10-01',   0  ,NULL       ,0.3225 ,              0 ,       NULL ,'INV1110011',          0 ,             0 ,'postpaid'    ,           2 ,      3); 
INSERT INTO `customrates`(`id`,`user_id`,`destinationgroup_id`) VALUES (1,3,1);
INSERT INTO `vouchers`(`id`,`number`  ,`tag`,`credit_with_vat`,`vat_percent`,`user_id`,`use_date`,`active_till`,`currency`,`payment_id`,`active`,`tax_id`) VALUES (2,'1234567890', 1   ,              20 ,           4 ,      0  ,'2010-01-01 01:01:01','2017-01-01 01:01:01','EUR',NULL,      1 ,      1 );
INSERT INTO `callerids`(`id`,`cli`,`device_id`,`description`,`added_at`,`banned`,`created_at`,`updated_at`,`ivr_id`,`comment`,`email_callback`) VALUES (  1 , 654  ,         5 ,''             ,'2011-10-01 13:36:59' ,      0 ,'2011-10-01 13:36:59','2011-10-01 13:36:59',      0 ,''         ,             0 );
INSERT INTO `groups`(`id`,`name`,`grouptype`) VALUES (2 ,'USERS GROUP','simple');
INSERT INTO `usergroups`(`id`,`user_id`,`group_id`,`gusertype`) VALUES (5 , 0 ,2 ,'user');
INSERT INTO `campaigns` (`id`, `name`, `campaign_type`, `status`, `start_time`, `stop_time`, `max_retries`, `retry_time`, `wait_time`, `user_id`, `device_id`, `callerid`, `owner_id`) VALUES (1, 'test_user_campaign', 'simple', 'disabled', '00:00:00', '23:59:59', 0, 120, 30, 2, 2, '', 0); 
INSERT INTO `campaigns` (`id`, `name`, `campaign_type`, `status`, `start_time`, `stop_time`, `max_retries`, `retry_time`, `wait_time`, `user_id`, `device_id`, `callerid`, `owner_id`) VALUES (2, 'test_reseller_campaign', 'simple', 'disabled', '00:00:00', '23:59:59', 0, 120, 30, 3, 6, '', 0);
INSERT INTO `ivrs` (`id`, `name`, `start_block_id`, `user_id`) VALUES (2, 'test_ivr', 2, 0);
INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES (6, 'test_tarrif', 'user_wholesale', 3, 'USD');
INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`) VALUES (503, 6, 2, NULL);
INSERT INTO `dids` (`id`, `did`, `status`, `user_id`, `device_id`, `subscription_id`, `reseller_id`, `closed_till`, `dialplan_id`, `language`, `provider_id`, `comment`, `call_limit`, `sound_file_id`, `grace_time`, `t_digit`, `t_response`) VALUES (3, '00000000001', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20);
INSERT INTO `dialplans` (`id`, `name`, `dptype`, `data1`, `data2`, `data3`, `data4`, `data5`, `data6`, `data7`, `data8`, `sound_file_id`, `user_id`) VALUES (7, 'test_dialplan', 'authbypin', '3', '3', '0', '0', NULL, NULL, NULL, NULL, 0, 3); 
INSERT INTO `dialplans` (`id`, `name`, `dptype`, `data1`, `data2`, `data3`, `data4`, `data5`, `data6`, `data7`, `data8`, `sound_file_id`, `user_id`) VALUES (8, 'test_pbx_function', 'pbxfunction', '6', '1', 'USD', '', NULL, NULL, NULL, NULL, NULL, 3);
INSERT INTO `phonebooks` (`id`, `user_id`, `number`, `name`, `added`, `card_id`, `speeddial`, `updated_at`) VALUES (2, 3, '37061111111', 'test_phonebook', '2012-04-05 15:19:28', 0, '876', '2012-04-05 15:19:28');
INSERT INTO `services` (`id`, `name`, `servicetype`, `destinationgroup_id`, `periodtype`, `price`, `owner_id`, `quantity`) VALUES (2, 'test_service', 'dialing', NULL, 'month', 0, 3, 1);
INSERT INTO `quickforwards_rules` (`id`, `name`, `user_id`, `rule_regexp`, `created_at`, `updated_at`) VALUES(1, 'test_rule', 3, '', '2012-04-06 17:16:48', '2012-04-06 17:16:48');
INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES (7, 'test_tarrif_providers', 'provider', 3, 'USD');
INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`) VALUES (2, 'test_provider', 'SIP', '', 'test_provider', 'please_change', '0.0.0.0', '5060', 1, 1, 7, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0);
INSERT INTO `terminators` (`id`, `name`, `user_id`) VALUES (2, 'test_terminator', 3);