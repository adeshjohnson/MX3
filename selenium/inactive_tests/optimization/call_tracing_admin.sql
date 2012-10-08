INSERT INTO `actions` (`id`, `user_id`, `date`, `action`, `data`, `data2`, `processed`, `target_type`, `target_id`, `data3`, `data4`) VALUES
(3, 0, '2012-10-08 12:29:12', 'login', '192.168.0.100', NULL, 0, '', NULL, NULL, NULL),
(4, 0, '2012-10-08 12:29:47', 'user_created', '', '', 0, 'user', 6, NULL, NULL),
(5, 0, '2012-10-08 12:29:48', 'device_created', '', '', 0, 'device', 9, NULL, NULL),
(6, 0, '2012-10-08 12:29:50', 'Device sent to Asterisk', '6', '', 0, 'device', 9, NULL, NULL);

INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES
(5, 1, '', '', '', '', '', '', '', '', '');

INSERT INTO `aratedetails` (`id`, `from`, `duration`, `artype`, `round`, `price`, `rate_id`, `start_time`, `end_time`, `daytype`) VALUES
(237, 1, -1, 'minute', 1, 2.000000000000000, 503, '00:00:00', '23:59:59', ''),
(238, 1, -1, 'minute', 1, 2.000000000000000, 504, '00:00:00', '23:59:59', ''),
(239, 1, -1, 'minute', 1, 2.000000000000000, 505, '00:00:00', '23:59:59', ''),
(240, 1, -1, 'minute', 1, 22.000000000000000, 506, '00:00:00', '23:59:59', ''),
(241, 1, -1, 'minute', 1, 22.000000000000000, 507, '00:00:00', '23:59:59', ''),
(242, 1, -1, 'minute', 1, 11.000000000000000, 508, '00:00:00', '23:59:59', ''),
(243, 1, -1, 'minute', 1, 11.000000000000000, 509, '00:00:00', '23:59:59', ''),
(244, 1, -1, 'minute', 1, 11.000000000000000, 510, '00:00:00', '23:59:59', '');

INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(280, 'System_time_zone_offset', '3', 0, NULL),
(281, 'Global_Number_Decimal', '.', 0, NULL),
(282, 'Integrity_Check', '0', 0, NULL),
(283, 'Default_device_server_id', '1', 0, NULL);

INSERT INTO `devicegroups` (`id`, `user_id`, `address_id`, `name`, `added`, `primary`) VALUES
(4, 6, 5, 'primary', '2012-10-08 12:29:47', 1);

INSERT INTO `devicecodecs` (`id`, `device_id`, `codec_id`, `priority`) VALUES
(5, 8, 1, 0),
(6, 8, 5, 0),
(9, 9, 1, 0),
(10, 9, 5, 0);

INSERT INTO `locationrules` (`id`, `location_id`, `name`, `enabled`, `cut`, `add`, `minlen`, `maxlen`, `lr_type`, `lcr_id`, `tariff_id`, `did_id`, `device_id`) VALUES
(2, 2, 'destrules', 1, '80', '9340', 9, 9, 'dst', 2, 6, NULL, NULL),
(3, 2, 'destrulesfree', 1, '90', '6140', 9, 9, 'dst', NULL, NULL, NULL, NULL),
(4, 2, 'cellrules', 1, '80', '9340', 9, 9, 'src', NULL, NULL, NULL, NULL);

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(1, 0, 0, 0, 0, 'Tax', '', '', '', 'Tax', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1),
(2, 0, 0, 0, 0, 'TAX', '', '', '', 'TAX', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1);

INSERT INTO `users` (`id`, `username`, `password`,`usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `c2c_service_active`, `temporary_id`, `send_invoice_types`, `call_limit`, `c2c_call_price`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`, `hide_destination_end`, `warning_email_hour`, `warning_balance_call`, `warning_balance_sound_file_id`, `own_providers`, `ignore_global_monitorings`, `currency_id`, `quickforwards_rule_id`, `spy_device_id`, `time_zone`, `minimal_charge`, `minimal_charge_start_at`, `webphone_allow_use`, `webphone_device_id`, `responsible_accountant_id`) VALUES
(6, 'user_admin', '8213544f82d739dbc044b7e3f6ed343b3bc7e543', 'user', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 2, 1, 0, 6, 0.000000000000000, NULL, 0, 0, 1, 9, -1.000000000000000, '', '0000000004', '2012-10-08', '', 123, '', 0.000000000000000, 5, '', 0, 0, 0, '2000-01-01 00:00:00', 'by4pf95cg2', 0, NULL, 0, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 2, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1);

INSERT INTO `lcrs` (`id`, `name`, `order`, `user_id`, `first_provider_percent_limit`, `failover_provider_id`, `no_failover`) VALUES
(2, 'speclcr', 'price', 0, 0.000000000000000, NULL, 0);

INSERT INTO `locations` (`id`, `name`, `user_id`) VALUES
(2, 'SpecRules', 0);

INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES
(6, 'spectariffre', 'user', 0, 'USD'),
(7, 'spectariffpro', 'provider', 0, 'USD');

INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(503, '00:00:00', '23:59:59', 2.000000000000000, 0.000000000000000, 511, 1, 0, ''),
(504, '00:00:00', '23:59:59', 3.000000000000000, 0.000000000000000, 512, 1, 0, ''),
(505, '00:00:00', '23:59:59', 4.000000000000000, 0.000000000000000, 513, 1, 0, ''),
(506, '00:00:00', '23:59:59', 5.000000000000000, 0.000000000000000, 514, 1, 0, ''),
(507, '00:00:00', '23:59:59', 6.000000000000000, 0.000000000000000, 515, 1, 0, ''),
(508, '00:00:00', '23:59:59', 7.000000000000000, 0.000000000000000, 516, 1, 0, ''),
(509, '00:00:00', '23:59:59', 8.000000000000000, 0.000000000000000, 517, 1, 0, ''),
(510, '00:00:00', '23:59:59', 9.000000000000000, 0.000000000000000, 518, 1, 0, ''),
(511, '00:00:00', '23:59:59', 9.000000000000000, 0.000000000000000, 519, 1, 0, '');

INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`) VALUES
(503, 6, 0, 1, 0.000000000000000),
(504, 6, 0, 2, 0.000000000000000),
(505, 6, 0, 473, 0.000000000000000),
(506, 6, 0, 21, 0.000000000000000),
(507, 6, 0, 22, 0.000000000000000),
(508, 6, 0, 24, 0.000000000000000),
(509, 6, 0, 25, 0.000000000000000),
(510, 6, 0, 478, 0.000000000000000),
(511, 7, 5, NULL, NULL),
(512, 7, 19, NULL, NULL),
(513, 7, 70, NULL, NULL),
(514, 7, 11358, NULL, NULL),
(515, 7, 136, NULL, NULL),
(516, 7, 11366, NULL, NULL),
(517, 7, 272, NULL, NULL),
(518, 7, 11381, NULL, NULL),
(519, 7, 11393, NULL, NULL);

INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`) VALUES
(8, 'prov8', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 5060, 0, 8, NULL, '4s89h73z6h', 0, 'specpro', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', '2000', '', 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 2, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', NULL, 'no', 0),
(9, '1001', 'dynamic', 'u4xad161u45q', 'mor_local', '0.0.0.0', 5060, 0, 9, NULL, '1001', 0, '1001', 'SIP', 6, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 4, 'rfc2833', NULL, NULL, NULL, NULL, 'no', 'no', NULL, 'no', 'no', 2, 'specdevice', 0, 0, '768114', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, '', 0, NULL, 0, -1, 0, 0, 0, 0, 0, 0, 'udp', NULL, 'no', 0);

INSERT INTO `extlines` (`id`, `context`, `exten`, `priority`, `app`, `appdata`, `device_id`) VALUES
(109, 'mor_local', '1001', 1, 'NoOp', '${MOR_MAKE_BUSY}', 9),
(110, 'mor_local', '1001', 2, 'GotoIf', '$["${MOR_MAKE_BUSY}" = "1"]?201', 9),
(111, 'mor_local', '1001', 3, 'GotoIf', '$[${LEN(${CALLED_TO})} > 0]?4:6', 9),
(112, 'mor_local', '1001', 4, 'NoOp', 'CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}', 9),
(113, 'mor_local', '1001', 5, 'Goto', '1001,7', 9),
(114, 'mor_local', '1001', 6, 'Set', 'CALLED_TO=${EXTEN}', 9),
(115, 'mor_local', '1001', 7, 'NoOp', 'MOR starts', 9),
(116, 'mor_local', '1001', 8, 'GotoIf', '$[${LEN(${CALLERID(NAME)})} > 0]?11:9', 9),
(117, 'mor_local', '1001', 9, 'GotoIf', '$[${LEN(${mor_cid_name})} > 0]?10:11', 9),
(118, 'mor_local', '1001', 10, 'Set', 'CALLERID(NAME)=${mor_cid_name}', 9),
(119, 'mor_local', '1001', 11, 'Dial', 'SIP/1001,60', 9),
(120, 'mor_local', '1001', 12, 'GotoIf', '$[$["${DIALSTATUS}" = "CHANUNAVAIL"]|$["${DIALSTATUS}" = "CONGESTION"]]?301', 9),
(121, 'mor_local', '1001', 13, 'GotoIf', '$["${DIALSTATUS}" = "BUSY"]?201', 9),
(122, 'mor_local', '1001', 14, 'GotoIf', '$["${DIALSTATUS}" = "NOANSWER"]?401', 9),
(123, 'mor_local', '1001', 15, 'Hangup', '', 9),
(124, 'mor_local', '1001', 401, 'NoOp', 'NO ANSWER', 9),
(125, 'mor_local', '1001', 402, 'Hangup', '', 9),
(126, 'mor_local', '1001', 201, 'NoOp', 'BUSY', 9),
(127, 'mor_local', '1001', 202, 'GotoIf', '${LEN(${MOR_CALL_FROM_DID}) = 1}?203:mor,BUSY,1', 9),
(128, 'mor_local', '1001', 203, 'Busy', '10', 9),
(129, 'mor_local', '1001', 301, 'NoOp', 'FAILED', 9),
(130, 'mor_local', '1001', 302, 'GotoIf', '${LEN(${MOR_CALL_FROM_DID}) = 1}?303:mor,FAILED,1', 9),
(131, 'mor_local', '1001', 303, 'Congestion', '4', 9);

INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`, `balance`) VALUES
(2, 'specpro', 'SIP', '', 'specpro', 'please_change', '0.0.0.0', '5060', 1, 1, 7, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, '', 0, '', 0, 0, 0, 0, 0.000000000000000);

INSERT INTO `serverproviders` (`id`, `server_id`, `provider_id`) VALUES
(1, 1, 2);

INSERT INTO `lcrproviders` (`id`, `lcr_id`, `provider_id`, `active`, `priority`, `percent`) VALUES
(2, 2, 2, 1, 1, 0);

INSERT INTO `voicemail_boxes` (`uniqueid`, `context`, `mailbox`, `password`, `fullname`, `email`, `pager`, `tz`, `attach`, `saycid`, `dialout`, `callback`, `review`, `operator`, `envelope`, `sayduration`, `saydurationm`, `sendvoicemail`, `delete`, `nextaftercmd`, `forcename`, `forcegreetings`, `hidefromdir`, `stamp`, `device_id`) VALUES
(8, 'default', '1001', '', ' ', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2012-10-08 12:29:48', 9);