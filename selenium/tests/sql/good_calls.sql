#dids
delete from dids;
insert into `dids` (`id`, `did`, `status`, `user_id`, `device_id`, `subscription_id`, `reseller_id`, `closed_till`, `dialplan_id`, `language`, `provider_id`, `comment`, `call_limit`, `sound_file_id`, `grace_time`, `t_digit`, `t_response`, `reseller_comment`, `cid_name_prefix`, `tonezone`, `call_count`, `cc_tariff_id`) values
(1, '37063042438', 'active', 5, 12, 0, 3, '2006-01-01 00:00:00', 0, 'en', 1, null, 0, 0, 0, 10, 20, null, null, null, 1, 0),
(2, '37093042422', 'active', 2, 10, 0, 0, '2010-06-23 00:00:00', 0, 'en', 1, null, 0, 0, 0, 10, 20, null, null, null, 1, 0);
#devices
INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`, `tell_rate`) VALUES
(8, 'prov8', 'sip.kolmisoft.com', 'rq71j44087x2', 'mor', '0.0.0.0', 5060, 0, 8, NULL, 'zprf75s974', 0, '40060', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', '2000', '', 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', NULL, 'no', 0, 0),
(10, '1011', 'dynamic', '123123123123', 'mor_local', '0.0.0.0', 5060, 0, 10, '"370600" <370600>', '1011', 0, '1011', 'SIP', 2, 2, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 0, 'rfc2833', NULL, NULL, NULL, NULL, 'no', 'no', NULL, 'no', 'no', 1, 'SIP_device', 0, 0, '234469', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 110, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, '', 0, NULL, 0, -1, 0, 0, 0, 0, 0, 0, 'udp', NULL, 'no', 0, 0),
(12, '1010', 'dynamic', '456456456456', 'mor_local', '0.0.0.0', 5060, 0, 12, '"40060" <40060>', '1010', 0, '1010', 'SIP', 5, 1, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 3, 'rfc2833', NULL, NULL, NULL, NULL, 'no', 'no', NULL, 'no', 'no', 2, 'SIP_device_re', 0, 0, '998858', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, '', 0, NULL, 0, -1, 0, 0, 0, 0, 0, 0, 'udp', NULL, 'no', 0, 0);
#Voicemail boxes
INSERT INTO `voicemail_boxes` (`uniqueid`, `context`, `mailbox`, `password`, `fullname`, `email`, `pager`, `tz`, `attach`, `saycid`, `dialout`, `callback`, `review`, `operator`, `envelope`, `sayduration`, `saydurationm`, `sendvoicemail`, `delete`, `nextaftercmd`, `forcename`, `forcegreetings`, `hidefromdir`, `stamp`, `device_id`) VALUES
(13, 'default', '1011', '', 'Test User #1', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2012-11-29 11:11:05', 10),
(26, 'default', '1010', '', 'User Resellers', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2012-11-29 11:11:33', 12);
#providers
INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`, `balance`) VALUES
(2, 'SIP_provider', 'SIP', '', '40060', 'rq71j44087x2', 'sip.kolmisoft.com', '5060', 1, 1, 1, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, '', 0, '', 0, 0, 0, 0, 0.000000000000000);
#calls
INSERT INTO `calls` (`id`, `calldate`, `clid`, `src`, `dst`, `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`, `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `peerip`, `recvip`, `sipfrom`, `uri`, `useragent`, `peername`, `t38passthrough`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`, `dst_user_id`) VALUES
(29, '2012-11-21 11:18:19', '"370600" <370600>', '370600', '37063042438', '', 'SIP/1011-00000000', '', '', '', 20, 18, 'ANSWERED', 0, '10', '1353489499.0', '', 10, 12, 0, 0.09, 0, 0, 0, 18, 0, 2, 0, 18, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 0.06, 0.03, '37063042438', 1, 1, '192.168.0.134', '192.168.0.134', 19.423, 17.839, 18, 5),
(30, '2012-11-21 11:19:48', '"40060" <40060>', '40060', '37093042422', '', 'SIP/1010-00000002', '', '', '', 18, 13, 'ANSWERED', 0, '12', '1353489588.2', '', 12, 10, 0, 0.13, 0, 0, -0, 13, -0, 5, 0, 13, 0, 3, 0, 13, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 0.108333, 0.086667, '37093042422', 1, 2, '192.168.0.134', '192.168.0.134', 17.019, 12.31, 13, 2),
(31, '2012-11-21 11:21:48', '"370600" <370600>', '370600', '37063042438', '', 'SIP/1011-00000004', '', '', '', 372, 370, 'ANSWERED', 0, '10', '1353489708.4', '', 10, 12, 0, 1.85, 0, 0, -0, 370, -0, 2, 0, 370, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 1.233333, 0.616667, '37063042438', 1, 1, '192.168.0.134', '192.168.0.134', 371.03, 369.381, 370, 5),
(32, '2012-11-21 11:28:02', '"40060" <40060>', '40060', '37093042422', '', 'SIP/1010-00000006', '', '', '', 169, 168, 'ANSWERED', 0, '12', '1353490082.6', '', 12, 10, 0, 1.68, 0, 0, -0, 168, -0, 5, 0, 168, 0, 3, 0, 168, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 1.4, 1.12, '37093042422', 1, 2, '192.168.0.134', '192.168.0.134', 168.776, 167.617, 168, 2),
(33, '2012-11-21 11:31:04', '"370600" <370600>', '370600', '37060064753', '', 'SIP/1011-00000008', '', '', '', 112, 106, 'ANSWERED', 0, '10', '1353490264.8', '', 10, 0, 0, 0, 0, 2, 0.12, 106, 0.212, 2, 0.52, 106, 0.918667, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '3706', 1, 16, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '192.168.0.134', 'sip.kolmisoft.com', 111.529, 105.216, 106, 0),
(34, '2012-11-21 11:33:04', '"40060" <40060>', '40060', '37060064753', '', 'SIP/1010-0000000a', '', '', '', 67, 58, 'ANSWERED', 0, '12', '1353490384.10', '', 12, 0, 0, 0, 0, 2, 0.12, 58, 0.116, 5, 0.92, 58, 0.889333, 3, 0.52, 58, 0.502667, NULL, NULL, NULL, NULL, '370600', 1, 16, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '192.168.0.134', 'sip.kolmisoft.com', 66.256, 57.062, 58, 0),
(35, '2012-11-21 11:39:47', '"370600" <370600>', '370600', '37063042438', '', 'SIP/1011-0000000c', '', '', '', 274, 273, 'ANSWERED', 0, '10', '1353490787.12', '', 10, 12, 0, 1.365, 0, 0, -0, 273, -0, 2, 0, 273, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 0.91, 0.455, '37063042438', 1, 1, '192.168.0.134', '192.168.0.134', 273.271, 272.072, 273, 5),
(36, '2012-11-21 11:44:25', '"40060" <40060>', '40060', '37093042422', '', 'SIP/1010-0000000e', '', '', '', 135, 134, 'ANSWERED', 0, '12', '1353491065.14', '', 12, 10, 0, 1.34, 0, 0, -0, 134, -0, 5, 0, 134, 0, 3, 0, 134, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 1.116667, 0.893333, '37093042422', 1, 2, '192.168.0.134', '192.168.0.134', 134.904, 133.895, 134, 2),
(37, '2012-11-21 11:46:43', '"40060" <40060>', '40060', '37060064753', '', 'SIP/1010-00000010', '', '', '', 1, 0, 'FAILED', 0, '12', '1353491203.16', '', 12, 0, 0, 0, 0, 2, 0.12, 0, 0, 5, 0.92, 0, 0, 3, 0, 0, 0, NULL, NULL, NULL, NULL, '370600', 1, 34, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '192.168.0.134', 'sip.kolmisoft.com', 0.178, 0, 0, 0),
(38, '2012-11-21 11:46:49', '"40060" <40060>', '40060', '37060064753', '', 'SIP/1010-00000012', '', '', '', 2, 0, 'FAILED', 0, '12', '1353491209.18', '', 12, 0, 0, 0, 0, 2, 0.12, 0, 0, 5, 0.92, 0, 0, 3, 0, 0, 0, NULL, NULL, NULL, NULL, '370600', 1, 34, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '192.168.0.134', 'sip.kolmisoft.com', 1.322, 0, 0, 0),
(39, '2012-11-21 11:47:02', '"370600" <370600>', '370600', '37060064753', '', 'SIP/1011-00000014', '', '', '', 112, 104, 'ANSWERED', 0, '10', '1353491222.20', '', 10, 0, 0, 0, 0, 2, 0.12, 104, 0.208, 2, 0.52, 104, 0.901333, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '3706', 1, 16, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '192.168.0.134', 'sip.kolmisoft.com', 111.635, 103.381, 104, 0),
(40, '2012-11-21 11:48:58', '"40060" <40060>', '40060', '37060064753', '', 'SIP/1010-00000016', '', '', '', 1, 0, 'FAILED', 0, '12', '1353491338.22', '', 12, 0, 0, 0, 0, 2, 0.12, 0, 0, 5, 0.92, 0, 0, 3, 0, 0, 0, NULL, NULL, NULL, NULL, '370600', 1, 34, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '192.168.0.134', 'sip.kolmisoft.com', 0.137, 0, 0, 0),
(41, '2012-11-21 11:49:30', '"370600" <370600>', '370600', '37060064753', '', 'SIP/1011-00000018', '', '', '', 13, 0, 'BUSY', 0, '10', '1353491370.24', '', 10, 0, 0, 0, 0, 2, 0.12, 0, 0, 2, 0.52, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '3706', 1, 17, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '192.168.0.134', 'sip.kolmisoft.com', 12.815, 0, 0, 0),
(42, '2012-11-21 11:49:52', '"370600" <370600>', '370600', '37060064753', '', 'SIP/1011-0000001a', '', '', '', 64, 0, 'BUSY', 0, '10', '1353491392.26', '', 10, 0, 0, 0, 0, 2, 0.12, 0, 0, 2, 0.52, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '3706', 1, 21, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '192.168.0.134', 'sip.kolmisoft.com', 63.723, 0, 0, 0),
(43, '2012-11-21 11:51:36', '"40060" <40060>', '40060', '37093042422', '', 'SIP/1010-0000001c', '', '', '', 125, 124, 'ANSWERED', 0, '12', '1353491496.28', '', 12, 10, 0, 1.24, 0, 0, -0, 124, -0, 5, 0, 124, 0, 3, 0, 124, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 1.033333, 0.826667, '37093042422', 1, 2, '192.168.0.134', '192.168.0.134', 124.505, 123.055, 124, 2),
(44, '2012-11-21 11:53:44', '"370600" <370600>', '370600', '37063042438', '', 'SIP/1011-0000001e', '', '', '', 137, 135, 'ANSWERED', 0, '10', '1353491624.30', '', 10, 12, 0, 0.675, 0, 0, -0, 135, -0, 2, 0, 135, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 0.45, 0.225, '37063042438', 1, 1, '192.168.0.134', '192.168.0.134', 136.895, 134.445, 135, 5),
(45, '2012-11-21 11:56:06', '"370600" <370600>', '370600', '37060064753', '', 'SIP/1011-00000020', '', '', '', 185, 176, 'ANSWERED', 0, '10', '1353491766.32', '', 10, 0, 0, 0, 0, 2, 0.12, 176, 0.352, 2, 0.52, 176, 1.525333, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '3706', 1, 16, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '192.168.0.134', 'sip.kolmisoft.com', 184.71, 175.135, 176, 0),
(46, '2012-11-29 10:04:53', '"370600" <370600>', '370600', '37063042438', '', 'SIP/1011-00000000', '', '', '', 1, 0, 'FAILED', 0, '10', '1354176293.0', '', 10, 12, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '', 1, 20, 'Local', '', '', '', '', '', '', 0, 0, 0, '37063042438', 1, 1, '0.0.0.0', '0.0.0.0', 0.023, 0, 0, 5),
(47, '2012-11-29 10:05:40', '"40060" <40060>', '40060', '37093042422', '', 'SIP/1010-00000001', '', '', '', 43, 41, 'ANSWERED', 0, '12', '1354176340.1', '', 12, 10, 0, 0.41, 0, 0, 0, 41, 0, 5, 0, 41, 0, 3, 0, 41, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 0.341667, 0.273333, '37093042422', 1, 2, '0.0.0.0', '0.0.0.0', 42.03, 40.725, 41, 2),
(48, '2012-11-29 10:06:26', '"370600" <370600>', '370600', '37063042438', '', 'SIP/1011-00000003', '', '', '', 56, 54, 'ANSWERED', 0, '10', '1354176386.3', '', 10, 12, 0, 0.27, 0, 0, -0, 54, -0, 2, 0, 54, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 0.18, 0.09, '37063042438', 1, 1, '0.0.0.0', '0.0.0.0', 55.241, 53.191, 54, 5),
(49, '2012-11-29 10:07:24', '"370600" <370600>', '370600', '37060064753', '', 'SIP/1011-00000005', '', '', '', 190, 183, 'ANSWERED', 0, '10', '1354176444.5', '', 10, 0, 0, 0, 0, 2, 0.12, 183, 0.366, 2, 0.52, 183, 1.586, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '3706', 1, 16, 'Local', '', '', '', '', '', '', 0, 0, 0, '37060064753', 0, 0, '0.0.0.0', 'sip.kolmisoft.com', 189.709, 182.838, 183, 0),
(50, '2012-11-29 10:10:39', '"40060" <40060>', '40060', '37093042422', '', 'SIP/1010-00000007', '', '', '', 254, 253, 'ANSWERED', 0, '12', '1354176639.7', '', 12, 10, 0, 2.53, 0, 0, -0, 253, -0, 5, 0, 253, 0, 3, 0, 253, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 2.108333, 1.686667, '37093042422', 1, 2, '0.0.0.0', '0.0.0.0', 253.985, 252.629, 253, 2),
(51, '2012-11-29 10:16:26', '"40060" <40060>', '40060', '37093042422', '', 'SIP/1010-00000009', '', '', '', 157, 156, 'ANSWERED', 0, '12', '1354176986.9', '', 12, 10, 0, 1.56, 0, 0, -0, 156, -0, 5, 0, 156, 0, 3, 0, 156, 0, NULL, NULL, NULL, NULL, '', 1, 16, 'Local', '', '', '', '', '', '', 0, 1.3, 1.04, '37093042422', 1, 2, '0.0.0.0', '0.0.0.0', 156.673, 155.465, 156, 2);
#Recordings
INSERT INTO `recordings` (`id`, `datetime`, `src`, `dst`, `src_device_id`, `dst_device_id`, `call_id`, `user_id`, `path`, `deleted`, `send_time`, `comment`, `size`, `uniqueid`, `visible_to_user`, `dst_user_id`, `local`, `visible_to_dst_user`) VALUES
(9, '2012-11-29 10:05:40', '40060', '37093042422', 12, 10, 30, 5, '', 0, NULL, '', 165198.000000000000000, '1354176340.1', 1, 2, 1, 1),
(10, '2012-11-29 10:06:26', '370600', '37063042438', 10, 12, 31, 2, '', 0, NULL, '', 214413.000000000000000, '1354176386.3', 1, 5, 1, 1),
(11, '2012-11-29 10:07:24', '370600', '37060064753', 10, 0, 32, 2, '', 0, NULL, '', 736235.000000000000000, '1354176444.5', 1, 0, 1, 0),
(12, '2012-11-29 10:10:39', '40060', '37093042422', 12, 10, 33, 5, '', 0, NULL, '', 1012715.000000000000000, '1354176639.7', 1, 2, 1, 1),
(13, '2012-11-29 10:16:26', '40060', '37093042422', 12, 10, 34, 5, '', 0, NULL, '', 624640.000000000000000, '1354176986.9', 1, 2, 1, 1);
