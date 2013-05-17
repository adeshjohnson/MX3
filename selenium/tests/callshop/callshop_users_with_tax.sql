/*group*/
insert into `groups` values (10,'Test_shop','callshop',0,'',1);
/* taxes*/
INSERT INTO `taxes` (`id`,`tax1_enabled`,`tax2_enabled`,`tax3_enabled`,`tax4_enabled`,`tax1_name`,`tax2_name`,`tax3_name`,`tax4_name`,`total_tax_name`,`tax1_value`,`tax2_value`,`tax3_value`,`tax4_value`,`compound_tax`)
VALUES              (17  ,1             ,0             ,0             ,0             ,'Tax1'     ,''         ,''         ,''         ,'Taxx'          ,60          ,0           ,0           ,0           ,1),
                    (18  ,1             ,1             ,0             ,0             ,'Tax3'     ,'Tax4'     ,''         ,''         ,'Taxxx'         ,30          ,20          ,0           ,0           ,1),
                    (19  ,1             ,1             ,1             ,1             ,'Tax5'     ,'Tax6'     ,'Tax7'     ,'Tax8'     ,'Tax1x'         ,10          ,10          ,5           ,30          ,1);
/* callshop manager and 3 users */
INSERT INTO `users` (`id`, `username`, `password`, `usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`,`temporary_id`, `send_invoice_types`, `call_limit`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`, `hide_destination_end`, `warning_email_hour`, `warning_balance_call`, `warning_balance_sound_file_id`, `own_providers`, `ignore_global_monitorings`, `currency_id`, `quickforwards_rule_id`, `spy_device_id`, `time_zone`, `minimal_charge`, `minimal_charge_start_at`, `webphone_allow_use`, `webphone_device_id`, `responsible_accountant_id`) VALUES
 (16, 'cs_manager', 'e10f43b9', 'user', 0, 'Callshop manager', '#1', 3.000000000000000, 1, 20.000000000000000, 0.000000000000000, 1, 1, 0, 2, 0.000000000000000, '2010-01-01 00:00:00', 0, 0, 1, 0, -1.000000000000000, NULL, NULL, NULL, NULL, NULL, NULL, 18.000000000000000, 6, NULL, 0, 0, 0, '2011-01-01 00:00:00', 'b9x18wd3pa', NULL, 1, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2021-01-01', 15, 0, 0, 0, NULL, 100, 0, 0.000000000000000, 0, 20, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1),
 (17, 'Test_user_1', '5d604a4d', 'user', 0, 'Callshop user 1', '#1', 3.000000000000000, 1, 13.000000000000000, 0.000000000000000, 1, 1, 1, 2, 0.000000000000000, '2010-01-01 00:00:00', 0, 0, 1, 0, -1.000000000000000, NULL, NULL, NULL, NULL, NULL, NULL, 18.000000000000000, 5, NULL, 0, 0, 0, '2011-01-01 00:00:00', '47n9rcug79', NULL, 1, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2021-01-01', 15, 0, 0, 0, NULL, 100, 0, 0.000000000000000, 0, 19, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1),
 (18, 'Test_user_2', 'aaaea87d', 'user', 0, 'Callshop user 2', '#1', 3.000000000000000, 1, 10.000000000000000, 0.000000000000000, 1, 1, 0, 2, 0.000000000000000, '2010-01-01 00:00:00', 0, 0, 1, 0, -1.000000000000000, NULL, NULL, NULL, NULL, NULL, NULL, 18.000000000000000, NULL, NULL, 0, 0, 0, '2011-01-01 00:00:00', NULL, NULL, 1, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2021-01-01', 15, 0, 0, 0, NULL, 100, 0, 0.000000000000000, 0, 17, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1),
 (19, 'Test_user_3', '6a0f10e8', 'user', 0, 'Callshop user 3', '#1', 3.000000000000000, 1, 14.000000000000000, 0.000000000000000, 1, 1, 0, 2, 0.000000000000000, '2011-01-01 00:00:00', 0, 0, 1, 0, -1.000000000000000, NULL, NULL, NULL, NULL, NULL, NULL, 18.000000000000000, NULL, NULL, 0, 0, 0, '2011-01-01 00:00:00', NULL,  NULL, 1, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2021-01-01', 15, 0, 0, 0, NULL, 100, 0, 0.000000000000000, 0, 18, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1);

/* devices for cs_users */
INSERT INTO `devices` (`id`, `name`, `host`  , `secret`, `context`  , `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`    , `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow` , `deny`          , `permit`        , `nat` , `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`) VALUES
                      (11  ,'110'  ,'dynamic','110'    ,'mor_local' ,'0.0.0.0',0      ,1175892667   ,   2          ,'\"110\" <110>','110'      ,      0,              '110'         ,'IAX2',          17,         0,               1,                    0,         0,   'no'       ,'all'        ,'all'  ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'  ,'yes'        ,''          ,'no'           ,NULL,             'rfc2833', NULL,         NULL,           NULL,        NULL,        'no'         ,'no'       ,'no'         ,'never'         ,'no',             1,       'Test Device for cs_user 1',       0    ,0               ,NULL   ,0             ,0,               60,                    60,                'no',             NULL,          0,     'no',          60,           0,               NULL,                   0,                   0           ,'yes',         'yes',         0,       0,             0                       ,0              ,NULL),
(12,'111','dynamic','110','mor_local','0.0.0.0',0,1175892667,2,'\"111\" <111>','111',0,'110','IAX2',18,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for cs_user 2',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL), 
(13,'112','dynamic','112','mor_local','0.0.0.0',0,1175892667,2,'\"112\" <112>','112',0,'110','IAX2',19,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for cs_user 3',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL);

Update users set time_zone = 'Vilnius';

