INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES
(5, 1, '', '', '', '', '', '', '', '', ''),
(6, 1, '', '', '', '', '', '', '', '', ''),
(7, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(8, 1, '', '', '', '', '', '', '', '', '');

INSERT INTO `aratedetails` (`id`, `from`, `duration`, `artype`, `round`, `price`, `rate_id`, `start_time`, `end_time`, `daytype`) VALUES
(237, 1, -1, 'minute', 1, 0.200000000000000, 504, '00:00:00', '23:59:59', ''),
(238, 1, -1, 'minute', 1, 0.200000000000000, 505, '00:00:00', '23:59:59', ''),
(239, 1, -1, 'minute', 1, 0.200000000000000, 506, '00:00:00', '23:59:59', ''),
(240, 1, -1, 'minute', 1, 0.200000000000000, 507, '00:00:00', '23:59:59', ''),
(241, 1, -1, 'minute', 1, 0.200000000000000, 508, '00:00:00', '23:59:59', ''),
(242, 1, -1, 'minute', 1, 0.200000000000000, 509, '00:00:00', '23:59:59', ''),
(243, 1, -1, 'minute', 1, 0.200000000000000, 510, '00:00:00', '23:59:59', ''),
(244, 1, -1, 'minute', 1, 0.200000000000000, 511, '00:00:00', '23:59:59', ''),
(245, 1, -1, 'minute', 1, 2.000000000000000, 512, '00:00:00', '23:59:59', ''),
(246, 1, -1, 'minute', 1, 2.000000000000000, 513, '00:00:00', '23:59:59', ''),
(247, 1, -1, 'minute', 1, 2.000000000000000, 514, '00:00:00', '23:59:59', ''),
(248, 1, -1, 'minute', 1, 22.000000000000000, 515, '00:00:00', '23:59:59', ''),
(249, 1, -1, 'minute', 1, 22.000000000000000, 516, '00:00:00', '23:59:59', ''),
(250, 1, -1, 'minute', 1, 11.000000000000000, 517, '00:00:00', '23:59:59', ''),
(251, 1, -1, 'minute', 1, 11.000000000000000, 518, '00:00:00', '23:59:59', ''),
(252, 1, -1, 'minute', 1, 11.000000000000000, 519, '00:00:00', '23:59:59', '');

INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(403, 'Default_device_location_id', '3', 3, NULL),

INSERT INTO `devicegroups` (`id`, `user_id`, `address_id`, `name`, `added`, `primary`) VALUES
(4, 6, 5, 'primary', '2012-10-07 11:33:52', 1),
(5, 7, 6, 'primary', '2012-10-08 09:10:59', 1);

INSERT INTO `devicecodecs` (`id`, `device_id`, `codec_id`, `priority`) VALUES
(5, 8, 1, 0),
(6, 8, 5, 0),
(9, 9, 1, 0),
(10, 9, 5, 0),
(7, 11, 1, 0),
(8, 11, 5, 0);

INSERT INTO `locationrules` (`id`, `location_id`, `name`, `enabled`, `cut`, `add`, `minlen`, `maxlen`, `lr_type`, `lcr_id`, `tariff_id`, `did_id`, `device_id`) VALUES
(2, 2, 'Int. prefix', 1, '00', '', 10, 20, 'dst', NULL, NULL, NULL, NULL);

update `ratedetails` set connection_fee=0.100000000000000 where id=1;
update `ratedetails` set connection_fee=0.100000000000000 where id=12;
update `ratedetails` set connection_fee=0.100000000000000 where id=14;
INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(503, '00:00:00', '23:59:59', 0.100000000000000, 0.000000000000000, 503, 1, 0, '');

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(2, 0, 0, 0, 0, 'TAX', '', '', '', 'TAX', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1),
(3, 0, 0, 0, 0, 'TAX', '', '', '', 'TAX', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1);


INSERT INTO `users` (`id`, `username`, `password`,`usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `c2c_service_active`, `temporary_id`, `send_invoice_types`, `call_limit`, `c2c_call_price`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`, `hide_destination_end`, `warning_email_hour`, `warning_balance_call`, `warning_balance_sound_file_id`, `own_providers`, `ignore_global_monitorings`, `currency_id`, `quickforwards_rule_id`, `spy_device_id`, `time_zone`, `minimal_charge`, `minimal_charge_start_at`, `webphone_allow_use`, `webphone_device_id`, `responsible_accountant_id`) VALUES
(6, 'rspro', '3fb748f090fb07345d547acd209f2380d23e6bda', 'reseller', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 1, 1, 0, 4, 0.000000000000000, NULL, 0, 0, 1, 0, -1.000000000000000, '', '0000000004', '2012-10-07', '', 123, '', 0.000000000000000, 5, '', 0, 0, 0, '2000-01-01 00:00:00', 'm3rv2ecbup', 0, NULL, 0, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 2, 1, 12, -1, -1, 0, 0, 1, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1),
(7, 'user_rspro', '581b476cac191591d67a7451b54f5a794ca913fa', 'user', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 1, 1, 0, 6, 0.000000000000000, NULL, 0, 0, 1, 9, -1.000000000000000, '', '0000000005', '2012-10-07', '', 123, '', 0.000000000000000, 7, '', 6, 0, 0, '2000-01-01 00:00:00', 'pmj9pgjm48', 0, NULL, 0, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, NULL, 0, 0, 0.000000000000000, 0, 3, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1);


INSERT INTO `lcrs` (`id`, `name`, `order`, `user_id`, `first_provider_percent_limit`, `failover_provider_id`, `no_failover`) VALUES
(2, 'speclcr', 'price', 6, 0.000000000000000, NULL, 0),
(3, 'lcr_for_call_tracing', 'price', 0, 0.000000000000000, NULL, 0),
(4, 'speclcr2', 'price', 3, 0.000000000000000, NULL, 0);

INSERT INTO `locations` (`id`, `name`, `user_id`) VALUES
(2, 'Default location', 6),
(3, 'SpecRules', 6);

DELETE FROM `tariffs`;
INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES
(1, 'Test Tariff', 'provider', 0, 'USD'),
(2, 'Test Tariff for Users', 'user_wholesale', 0, 'USD'),
(3, 'tariff', 'user', 3, 'USD'),
(4, 'Test Tariff + 0.1', 'user', 0, 'USD'),
(5, 'Test Tariff bad currency', 'provider', 0, 'AAA'),
(6, 'spectariffre', 'user', 6, 'USD'),
(7, 'spectariffpro', 'provider', 6, 'USD'),
(8, 'Pro_tariff_with_rate', 'provider', 0, 'USD'),
(9, 'Pro_tariff_without_rate', 'provider', 0, 'USD'),
(10, 'spectariffres', 'user', 3, 'USD'),
(11, 'spectariffprov', 'provider', 3, 'USD');

INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`) VALUES
(503, 1, 5, NULL, NULL),
(504, 4, 0, 1, 0.000000000000000),
(505, 4, 0, 2, 0.000000000000000),
(506, 4, 0, 473, 0.000000000000000),
(507, 4, 0, 21, 0.000000000000000),
(508, 4, 0, 22, 0.000000000000000),
(509, 4, 0, 26, 0.000000000000000),
(510, 4, 0, 27, 0.000000000000000),
(511, 4, 0, 28, 0.000000000000000),
(512, 6, 0, 1, 0.000000000000000),
(513, 6, 0, 2, 0.000000000000000),
(514, 6, 0, 473, 0.000000000000000),
(515, 6, 0, 21, 0.000000000000000),
(516, 6, 0, 22, 0.000000000000000),
(517, 6, 0, 24, 0.000000000000000),
(518, 6, 0, 25, 0.000000000000000),
(519, 6, 0, 478, 0.000000000000000);

INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`) VALUES
(8, 'prov8', '0.0.0.0', '', 'mor', '0.0.0.0', 5060, 0, 8, NULL, 'amqknbza7j', 0, '', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'no', '', 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 3, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', NULL, 'no', 0),
(9, 'prov_3', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 5060, 0, 8, '', 'drj2p5tatz', 0, 'prov_3', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', NULL, 'no', 0),
(10, 'prov_4', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 5060, 0, 9, '', 'a82evvykn4', 0, 'prov_4', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', NULL, 'no', 0),
(11, 'prov_5', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 5060, 0, 10, '', '5mt6ceecb4', 0, 'prov_5', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', NULL, 'no', 0),
(12, 'prov_6', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 5060, 0, 11, '', 'vgm4v20313', 0, 'prov_6', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', NULL, 'no', 0);

INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`, `balance`) VALUES
(2, 'specpro', 'SIP', '', '', '', '0.0.0.0', '5060', 1, 1, 7, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, '', 0, '', 0, 0, 6, 0, 0.000000000000000),
(3, 'active_with_rate', 'SIP', '', 'active_with_rate', 'please_change', '0.0.0.0', '5060', 1, 1, 8, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 0.000000000000000),
(4, 'active_without_rate', 'SIP', '', 'active_without_rate', 'please_change', '0.0.0.0', '5060', 1, 1, 9, 0, 0, '', '', 9, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 0.000000000000000),
(5, 'inactive_with_rate', 'SIP', '', 'inactive_with_rate', 'please_change', '0.0.0.0', '5060', 1, 1, 8, 0, 0, '', '', 10, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 0.000000000000000),
(6, 'inactive_without_rate', 'SIP', '', 'inactive_without_rate', 'please_change', '0.0.0.0', '5060', 1, 1, 9, 0, 0, '', '', 11, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 0.000000000000000),
(7, 'specprov', 'SIP', '', 'specprov', 'please_change', '0.0.0.0', '5060', 1, 1, 11, 0, 0, '', '', 13, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0, 0.000000000000000);

INSERT INTO `serverproviders` (`id`, `server_id`, `provider_id`) VALUES
(1, 1, 2),
(2, 1, 3);

INSERT INTO `devices` (`id`,`name`,`host`   ,`secret`      ,`context`  ,`ipaddr`,`port`,`regseconds`,`accountcode`,`callerid`,`extension`,`voicemail_active`,`username`,`device_type`,`user_id`,`primary_did_id`,`works_not_logged`,`forward_to`,`record`,`transfer`,`disallow`,`allow`    ,`deny`           ,`permit`         ,`nat`            ,`qualify`,`fullcontact`,`canreinvite`,`devicegroup_id`,`dtmfmode`,`callgroup`,`pickupgroup`,`fromuser`,`fromdomain`,`trustrpid`,`sendrpid`,`insecure`,`progressinband`,`videosupport`,`location_id`,`description`,`istrunk` ,`cid_from_dids`,`pin`   ,`tell_balance`,`tell_time`,`tell_rtime_when_left`,`repeat_rtime_every`,`t38pt_udptl`,`regserver`,`ani`,`promiscredir`,`timeout`,`process_sipchaninfo`,`temporary_id`,`allow_duplicate_calls`,`call_limit`,`lastms`,`faststart`,`h245tunneling`,`latency`,`grace_time`,`recording_to_email`,`recording_keep`,`recording_email`,`record_forced`,`fake_ring`,`save_call_log`,`mailbox`     ,`server_id`,`enable_mwi`,`authuser`,`requirecalltoken`,`language`)
VALUES                ( 13  ,1001  ,'dynamic','6mgs1bhnz4cy','mor_local',''      ,0     ,0           , 9           , NULL     ,1001       ,0                 ,1001      ,'SIP'        ,7        ,0               ,1                 ,0           ,0       ,'no'      ,'all'     ,'alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'            ,1000     ,NULL         ,'no'         ,NULL            ,'rfc2833' ,NULL       ,NULL         ,''        ,''          ,'no'       ,'no'      ,''        ,'no'            ,'no'         ,1             ,'specdevice' ,0         ,0              , 864193 ,0             ,0          ,60                    ,60                  ,'no'         ,NULL       ,0    ,'no'          ,60       ,0                    ,NULL          ,0                      ,0           ,0       ,'yes'      ,'yes'          ,0        ,NULL        ,0                   ,0               ,''               ,0              ,0          ,0              ,'1001@default',1          ,0           ,''        ,'no'              ,'en');
update conflines set value = 1 WHERE ( name = 'Default_device_location_id' and owner_id =6);
update conflines set value = 1 WHERE ( name = 'Default_device_location_id' and owner_id =3);
Update users set time_zone = 'UTC';