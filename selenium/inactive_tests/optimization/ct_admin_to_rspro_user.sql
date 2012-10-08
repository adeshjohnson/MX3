INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES
(5, 1, '', '', '', '', '', '', '', '', '');

INSERT INTO `aratedetails` (`id`, `from`, `duration`, `artype`, `round`, `price`, `rate_id`, `start_time`, `end_time`, `daytype`) VALUES
(237, 1, -1, 'minute', 1, 30.000000000000000, 503, '00:00:00', '23:59:59', ''),
(238, 1, -1, 'minute', 1, 30.000000000000000, 504, '00:00:00', '23:59:59', ''),
(239, 1, -1, 'minute', 1, 30.000000000000000, 505, '00:00:00', '23:59:59', ''),
(240, 1, -1, 'minute', 1, 8.000000000000000, 507, '00:00:00', '23:59:59', ''),
(241, 1, -1, 'minute', 1, 8.000000000000000, 508, '00:00:00', '23:59:59', ''),
(242, 1, -1, 'minute', 1, 8.000000000000000, 509, '00:00:00', '23:59:59', ''),
(243, 1, -1, 'minute', 1, 3.000000000000000, 510, '00:00:00', '23:59:59', ''),
(244, 1, -1, 'minute', 1, 3.000000000000000, 511, '00:00:00', '23:59:59', ''),
(245, 1, -1, 'minute', 1, 3.000000000000000, 512, '00:00:00', '23:59:59', '');

INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(280, 'System_time_zone_offset', '3', 0, NULL),
(281, 'Global_Number_Decimal', '.', 0, NULL),
(282, 'Integrity_Check', '0', 0, NULL),
(284, 'Company', 'KolmiSoft', 3, NULL),
(285, 'Company_Email', 'kolmitest@gmail.com', 3, NULL),
(286, 'Version', 'MOR 12', 3, NULL),
(287, 'Copyright_Title', ' by <a href=''http://www.kolmisoft.com'' target="_blank">Kolmisoft </a> 2006-2012', 3, NULL),
(288, 'Admin_Browser_Title', 'MOR 12', 3, NULL),
(289, 'Logo_Picture', 'logo/mor_logo.png', 3, NULL),
(290, 'Show_Rates_Without_Tax', '0', 3, NULL),
(291, 'Paypal_Default_Currency', '', 3, NULL),
(292, 'WebMoney_Default_Currency', 'USD', 3, NULL),
(293, 'WebMoney_SIM_MODE', '0', 3, NULL),
(294, 'Paypal_Enabled', '0', 3, NULL),
(295, 'PayPal_Email', '', 3, NULL),
(296, 'Paypal_Default_Currency', 'USD', 3, NULL),
(297, 'PayPal_Default_Amount', '10', 3, NULL),
(298, 'PayPal_Min_Amount', '5', 3, NULL),
(299, 'PayPal_Test', '', 3, NULL),
(300, 'WebMoney_Enabled', '0', 3, NULL),
(301, 'WebMoney_Purse', '', 3, NULL),
(302, 'WebMoney_Default_Amount', '10', 3, NULL),
(303, 'WebMoney_Min_Amount', '5', 3, NULL),
(304, 'WebMoney_Test', '1', 3, NULL),
(305, 'Default_device_type', 'SIP', 3, NULL),
(306, 'Default_device_dtmfmode', 'rfc2833', 3, NULL),
(307, 'Default_device_works_not_logged', '1', 3, NULL),
(308, 'Default_device_location_id', '2', 3, NULL),
(309, 'Default_device_timeout', '60', 3, NULL),
(310, 'Default_device_record', '0', 3, NULL),
(311, 'Default_device_call_limit', '0', 3, NULL),
(312, 'Default_device_nat', 'yes', 3, NULL),
(313, 'Default_device_voicemail_active', '', 3, NULL),
(314, 'Default_device_trustrpid', 'no', 3, NULL),
(315, 'Default_device_sendrpid', 'no', 3, NULL),
(316, 'Default_device_t38pt_udptl', 'no', 3, NULL),
(317, 'Default_device_promiscredir', 'no', 3, NULL),
(318, 'Default_device_progressinband', 'no', 3, NULL),
(319, 'Default_device_videosupport', 'no', 3, NULL),
(320, 'Default_device_allow_duplicate_calls', '0', 3, NULL),
(321, 'Default_device_tell_balance', '0', 3, NULL),
(322, 'Default_device_tell_time', '0', 3, NULL),
(323, 'Default_device_tell_rtime_when_left', '60', 3, NULL),
(324, 'Default_device_repeat_rtime_every', '60', 3, NULL),
(325, 'Default_device_permits', '0.0.0.0/0.0.0.0', 3, NULL),
(326, 'Default_device_qualify', '1000', 3, NULL),
(327, 'Default_device_host', 'dynamic', 3, NULL),
(328, 'Default_device_ipaddr', '', 3, NULL),
(329, 'Default_device_port', '', 3, NULL),
(330, 'Default_device_regseconds', 'no', 3, NULL),
(331, 'Default_device_canreinvite', 'no', 3, NULL),
(332, 'Default_device_canreinvite', 'no', 3, NULL),
(333, 'Default_device_istrunk', '0', 3, NULL),
(334, 'Default_device_ani', '0', 3, NULL),
(335, 'Default_device_callgroup', '', 3, NULL),
(336, 'Default_device_pickupgroup', '', 3, NULL),
(337, 'Default_device_fromuser', '', 3, NULL),
(338, 'Default_device_fromuser', '', 3, NULL),
(339, 'Default_device_insecure', '', 3, NULL),
(340, 'Default_device_process_sipchaninfo', '0', 3, NULL),
(341, 'Default_device_voicemail_box_email', '', 3, NULL),
(342, 'Default_device_voicemail_box_password', '', 3, NULL),
(343, 'Default_device_fake_ring', '', 3, NULL),
(344, 'Default_device_save_call_log', '', 3, NULL),
(345, 'Default_device_use_ani_for_cli', '', 3, NULL),
(346, 'Default_setting_device_caller_id_number', '', 3, NULL),
(347, 'Default_device_codec_alaw', '1', 3, NULL),
(348, 'Default_device_codec_ulaw', '0', 3, NULL),
(349, 'Default_device_codec_g723', '0', 3, NULL),
(350, 'Default_device_codec_g726', '0', 3, NULL),
(351, 'Default_device_codec_g729', '1', 3, NULL),
(352, 'Default_device_codec_gsm', '0', 3, NULL),
(353, 'Default_device_codec_ilbc', '0', 3, NULL),
(354, 'Default_device_codec_lpc10', '0', 3, NULL),
(355, 'Default_device_codec_speex', '0', 3, NULL),
(356, 'Default_device_codec_adpcm', '0', 3, NULL),
(357, 'Default_device_codec_slin', '0', 3, NULL),
(358, 'Default_device_codec_h261', '0', 3, NULL),
(359, 'Default_device_codec_h263', '0', 3, NULL),
(360, 'Default_device_codec_h263p', '0', 3, NULL),
(361, 'Default_device_codec_jpeg', '0', 3, NULL),
(362, 'Default_device_codec_png', '0', 3, NULL),
(363, 'Default_device_codec_h264', '0', 3, NULL),
(364, 'Default_device_cid_name', '', 3, NULL),
(365, 'Default_device_cid_number', '', 3, NULL),
(366, 'CSV_Separator', ',', 3, NULL),
(367, 'CSV_Decimal', '.', 3, NULL),
(368, 'Email_Batch_Size', '50', 3, NULL),
(369, 'Email_from', '', 3, NULL),
(370, 'Email_Smtp_Server', 'smtp.gmail.com', 3, NULL),
(371, 'Email_Domain', 'localhost.localdomain', 3, NULL),
(372, 'Email_Login', 'kolmitest998', 3, 0x31),
(373, 'Email_Password', 'kolmisoft9', 3, 0x31),
(374, 'Email_port', '25', 3, NULL),
(375, 'Default_device_qualify_time', '2000', 3, NULL),
(376, 'Default_device_voicemail_box', '1', 3, NULL),
(377, 'Default_device_fromdomain', '', 3, NULL),
(378, 'Default_device_server_id', '1', 0, NULL);

INSERT INTO `devicegroups` (`id`, `user_id`, `address_id`, `name`, `added`, `primary`) VALUES
(4, 6, 5, 'primary', '2012-10-08 12:43:16', 1);

INSERT INTO `devicecodecs` (`id`, `device_id`, `codec_id`, `priority`) VALUES
(5, 8, 1, 0),
(6, 8, 5, 0),
(9, 9, 1, 0),
(10, 9, 5, 0);

INSERT INTO `locationrules` (`id`, `location_id`, `name`, `enabled`, `cut`, `add`, `minlen`, `maxlen`, `lr_type`, `lcr_id`, `tariff_id`, `did_id`, `device_id`) VALUES
(2, 2, 'Int. prefix', 1, '00', '', 10, 20, 'dst', NULL, NULL, NULL, NULL),
(3, 3, 'Rul1', 1, '8', '370', 1, 100, 'dst', NULL, 7, NULL, NULL);

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(1, 0, 0, 0, 0, 'Tax', '', '', '', 'Tax', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1),
(2, 0, 0, 0, 0, 'TAX', '', '', '', 'TAX', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1);

INSERT INTO `users` (`id`, `username`, `password`,`usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `c2c_service_active`, `temporary_id`, `send_invoice_types`, `call_limit`, `c2c_call_price`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`, `hide_destination_end`, `warning_email_hour`, `warning_balance_call`, `warning_balance_sound_file_id`, `own_providers`, `ignore_global_monitorings`, `currency_id`, `quickforwards_rule_id`, `spy_device_id`, `time_zone`, `minimal_charge`, `minimal_charge_start_at`, `webphone_allow_use`, `webphone_device_id`, `responsible_accountant_id`) VALUES
(6, '102', '00e263ff6806064c016a643c6587b0d607a6a42d', 'user', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 2, 1, 0, 6, 0.000000000000000, NULL, 0, 0, 1, 9, -1.000000000000000, '', '0000000004', '2012-10-08', '', 123, '', 0.000000000000000, 5, '', 3, 0, 0, '2000-01-01 00:00:00', 'v4mysts8qv', 0, NULL, 0, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, NULL, 0, 0, 0.000000000000000, 0, 2, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 0.000000000000000, 0, NULL, 0, 0, -1);

INSERT INTO `user_translations` (`id`, `user_id`, `translation_id`, `position`, `active`) VALUES
(34, 3, 1, 1, 0),
(35, 3, 2, 2, 0),
(36, 3, 3, 3, 0),
(37, 3, 4, 4, 0),
(38, 3, 5, 5, 0),
(39, 3, 6, 6, 0),
(40, 3, 7, 7, 0),
(41, 3, 8, 8, 0),
(42, 3, 9, 9, 0),
(43, 3, 10, 10, 0),
(44, 3, 11, 11, 0),
(45, 3, 12, 12, 0),
(46, 3, 13, 13, 0),
(47, 3, 14, 14, 0),
(48, 3, 15, 15, 0),
(49, 3, 16, 16, 0),
(50, 3, 17, 17, 0),
(51, 3, 18, 18, 0),
(52, 3, 19, 19, 0),
(53, 3, 20, 100, 0),
(54, 3, 21, 101, 0),
(55, 3, 22, 102, 0),
(56, 3, 23, 103, 0),
(57, 3, 24, 104, 0),
(58, 3, 25, 105, 0),
(59, 3, 26, 106, 0),
(60, 3, 27, 107, 0),
(61, 3, 28, 108, 0),
(62, 3, 29, 109, 0),
(63, 3, 30, 108, 0),
(64, 3, 31, 100, 0),
(65, 3, 32, 32, 0),
(66, 3, 33, 110, 0);

INSERT INTO `lcrs` (`id`, `name`, `order`, `user_id`, `first_provider_percent_limit`, `failover_provider_id`, `no_failover`) VALUES
(2, 'lcras', 'price', 3, 0.000000000000000, NULL, 0);

INSERT INTO `locations` (`id`, `name`, `user_id`) VALUES
(2, 'Default location', 3),
(3, 'Loc1', 3);

UPDATE `ratedetails` SET rate=2.000000000000000 WHERE id=140;
INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(503, '00:00:00', '23:59:59', 2.000000000000000, 0.000000000000000, 506, 1, 0, '');

INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES
(6, 'tar1', 'user', 3, 'USD'),
(7, 'tar3', 'user', 3, 'USD'),
(8, 'tarprov', 'provider', 3, 'USD');

INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`) VALUES
(503, 4, 0, 249, 0.000000000000000),
(504, 4, 0, 250, 0.000000000000000),
(505, 4, 0, 251, 0.000000000000000),
(506, 8, 12502, NULL, NULL),
(507, 6, 0, 249, 0.000000000000000),
(508, 6, 0, 250, 0.000000000000000),
(509, 6, 0, 251, 0.000000000000000),
(510, 7, 0, 249, 0.000000000000000),
(511, 7, 0, 250, 0.000000000000000),
(512, 7, 0, 251, 0.000000000000000);

INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`) VALUES
(8, 'prov_2', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 5060, 0, 8, '', 'qjam255dpq', 0, 'prov_2', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 2, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', NULL, 'no', 0),
(9, '1001', 'dynamic', 't6wxwvycpvbw', 'mor_local', '0.0.0.0', 5060, 0, 9, NULL, '1001', 0, '1001', 'SIP', 6, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 4, 'rfc2833', NULL, NULL, NULL, NULL, 'no', 'no', NULL, 'no', 'no', 3, 'Dev1', 0, 0, '439174', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, '', 0, NULL, 0, -1, 0, 0, 0, 0, 0, 0, 'udp', NULL, 'no', 0);


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
(2, 'provas', 'SIP', '', 'provas', 'please_change', '0.0.0.0', '5060', 1, 1, 8, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0, 0.000000000000000);

INSERT INTO `serverproviders` (`id`, `server_id`, `provider_id`) VALUES
(1, 1, 2);

INSERT INTO `lcrproviders` (`id`, `lcr_id`, `provider_id`, `active`, `priority`, `percent`) VALUES
(2, 2, 2, 1, 1, 0);

INSERT INTO `voicemail_boxes` (`uniqueid`, `context`, `mailbox`, `password`, `fullname`, `email`, `pager`, `tz`, `attach`, `saycid`, `dialout`, `callback`, `review`, `operator`, `envelope`, `sayduration`, `saydurationm`, `sendvoicemail`, `delete`, `nextaftercmd`, `forcename`, `forcegreetings`, `hidefromdir`, `stamp`, `device_id`) VALUES
(8, 'default', '1001', '', ' ', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2012-10-08 12:43:20', 9);

