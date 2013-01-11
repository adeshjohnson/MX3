INSERT INTO `calls` (`id`, `calldate`, `clid`, `src`, `dst`, `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`, `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `peerip`, `recvip`, `sipfrom`, `uri`, `useragent`, `peername`, `t38passthrough`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`, `dst_user_id`) 
VALUES (50, '2010-12-26 20:05:25', '"10264" <10264>', '10264', '212678715807', '', 'SIP/10264-0978cd90', '', '', '', 22, 100, 'ANSWERED', 0, '313', '1287947125.136252', '', 13, 0, 0, 0, 0, 1, 0.149708, 21, 0.052398, 4, 0.2014, 21, 0.07049, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '212678', 1, 16, 'Local', '', '', '', '', '', '', 0, 0, 0, '212678715807', 0, 0, '83.39.121.175', '173.244.164.18', 21.264258, 20.270722, 21, NULL),
(51, '2010-12-25 20:05:25', '"10264" <10264>', '10264', '212678715807', '', 'SIP/10264-0978cd90', '', '', '', 22, 50, 'ANSWERED', 0, '313', '1287947125.136252', '', 13, 0, 0, 0, 0, 1, 0.149708, 21, 0.052398, 4, 0.2014, 21, 0.07049, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '212678', 1, 16, 'Local', '', '', '', '', '', '', 0, 0, 0, '212678715807', 0, 0, '83.39.121.175', '173.244.164.18', 21.264258, 20.270722, 21, NULL);

INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`, `tell_rate`, `trunk`, `proxy_port`) 
VALUES 
(13, '1004', 'dynamic', 'usgdtr2hhkpu', 'mor_local', '', 5060, 0, 13, NULL, '1004', 0, '1004', 'SIP', 4, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 2, 'rfc2833', NULL, NULL, '', '', 'no', 'no', '', 'no', 'no', 1, 'acc_device', 0, 0, '556331', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', NULL, '', 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp', 'no', '', 0, 0, 'no', 5060);