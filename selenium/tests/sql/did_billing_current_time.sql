#dids
delete from dids;
insert into `dids` (`id`, `did`, `status`, `user_id`, `device_id`, `subscription_id`, `reseller_id`, `closed_till`, `dialplan_id`, `language`, `provider_id`, `comment`, `call_limit`, `sound_file_id`, `grace_time`, `t_digit`, `t_response`, `reseller_comment`, `cid_name_prefix`, `tonezone`, `call_count`, `cc_tariff_id`) values
(1, '37063042438', 'active', 5, 12, 0, 3, '2006-01-01 00:00:00', 0, 'en', 1, null, 0, 0, 0, 10, 20, null, null, null, 1, 0),
(2, '37093042422', 'active', 2, 10, 0, 0, '2010-06-23 00:00:00', 0, 'en', 1, null, 0, 0, 0, 10, 20, null, null, null, 1, 0);
#devices
INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`, `tell_rate`) VALUES
(8, 'prov8', 'sip.kolmisoft.com', 'rq71j44087x2', 'mor', '0.0.0.0', 5060, 0, 8, NULL, 'zprf75s974', 0, '40060', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', '2000', '', 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', NULL, 'no', 0, 0),
(9, '1001', 'dynamic', 'f9va26ncfxu2', 'mor_local', '', 5060, 0, 9, NULL, '1001', 0, '1001', 'SIP', 2, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 0, 'rfc2833', NULL, NULL, '', '', 'no', 'no', '', 'no', 'no', 1, 'Netinkamas', 0, 0, '651859', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', NULL, '', 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp', NULL, '', 0, 0),
(10, '1011', 'dynamic', '123123123123', 'mor_local', '0.0.0.0', 5060, 0, 10, '"370600" <370600>', '1011', 0, '1011', 'SIP', 2, 2, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 0, 'rfc2833', NULL, NULL, NULL, NULL, 'no', 'no', NULL, 'no', 'no', 1, 'SIP_device', 0, 0, '234469', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, '', 0, NULL, 0, -1, 0, 0, 0, 0, 0, 0, 'udp', NULL, 'no', 0, 0),
(11, '1003', 'dynamic', 'k575g992gsxg', 'mor_local', '', 5060, 0, 11, NULL, '1003', 0, '1003', 'SIP', 5, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 3, 'rfc2833', NULL, NULL, '', '', 'no', 'no', '', 'no', 'no', 2, 'Nereikalingas_re', 0, 0, '787127', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', NULL, '', 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp', NULL, '', 0, 0),
(12, '1010', 'dynamic', '456456456456', 'mor_local', '0.0.0.0', 5060, 0, 12, '"40060" <40060>', '1010', 0, '1010', 'SIP', 5, 1, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 3, 'rfc2833', NULL, NULL, NULL, NULL, 'no', 'no', NULL, 'no', 'no', 2, 'SIP_device_re', 0, 0, '998858', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, '', 0, NULL, 0, -1, 0, 0, 0, 0, 0, 0, 'udp', NULL, 'no', 0, 0);
#providers
INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`, `balance`) VALUES
(2, 'SIP_provider', 'SIP', '', '40060', 'rq71j44087x2', 'sip.kolmisoft.com', '5060', 1, 1, 1, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, '', 0, '', 0, 0, 0, 0, 0.000000000000000);
#calls 
insert into `calls` (`id`, `calldate`           , `clid`             , `src`   , `dst`        , `dcontext`, `channel`          , `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`    , `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `peerip`, `recvip`, `sipfrom`, `uri`, `peername`, `t38passthrough`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`, `dst_user_id`) values
                    (29  , DATE_ADD(CURRENT_TIMESTAMP(), INTERVAL -10 MINUTE), '"370600" <370600>', '370600', '37063042438', ''        , 'sip/1011-00000000', ''          , ''       , ''        , 157       , 155      , 'answered'   , 0         , '10'         , '1352452726.0', ''         , 10             , 12             , 0          , 0.775      , 0        , 0            , 0              , 155               , 0               , 2        , 0           , 155          , 0           , 0            , 0              , 0                 , 0               , null        , null          , null             , null           , ''      , 1          , 16           , 'local'     , ''      , ''      , ''       , ''   , ''        , 0              , 0.516667        , 0.258333, '37063042438', 1, 1, '192.168.0.148', '192.168.0.148', 156.101348, 154.630811, 155, 5),
                    (30  , DATE_ADD(CURRENT_TIMESTAMP(), INTERVAL -10 MINUTE), '"40060" <40060>'  , '40060' , '37093042422', ''        , 'sip/1010-00000002', ''          , ''       , ''        , 281       , 278      , 'answered'   , 0         , '12'         , '1352452903.2', ''         , 12             , 10             , 0          , 2.78       , 0        , 0            , -0             , 278               , -0              , 5        , 0           , 278          , 0           , 3            , 0              , 278               , 0               , null        , null          , null             , null           , ''      , 1          , 16           , 'local'     , ''      , ''      , ''       , ''   , ''        , 0              , 2.316667        , 1.853333, '37093042422', 1, 2, '192.168.0.148', '192.168.0.148', 280.203538, 277.7584, 278, 2),
                    (31  , DATE_ADD(CURRENT_TIMESTAMP(), INTERVAL -10 MINUTE), '"370600" <370600>', '370600', '37063042438', ''        , 'sip/1011-00000004', ''          , ''       , ''        , 314       , 207      , 'answered'   , 0         , '10'         , '1352453188.4', ''         , 10             , 12             , 0          , 1.035      , 0        , 0            , -0             , 207               , -0              , 2        , 0           , 207          , 0           , 0            , 0              , 0                 , 0               , null        , null          , null             , null           , ''      , 1          , 16           , 'local'     , ''      , ''      , ''       , ''   , ''        , 0              , 0.69            , 0.345, '37063042438', 1, 1, '192.168.0.148', '192.168.0.148', 313.445519, 206.423912, 207, 5),
                    (32  , DATE_ADD(CURRENT_TIMESTAMP(), INTERVAL -10 MINUTE), '"40060" <40060>'  , '40060' , '37093042422', ''        , 'sip/1010-00000006', ''          , ''       , ''        , 139       , 137      , 'answered'   , 0         , '12'         , '1352453507.6', ''         , 12             , 10             , 0          , 1.37       , 0        , 0            , -0             , 137               , -0              , 5        , 0           , 137          , 0           , 3            , 0              , 137               , 0               , null        , null          , null             , null           , ''      , 1          , 16           , 'local'     , ''      , ''      , ''       , ''   , ''        , 0              , 1.141667        , 0.913333, '37093042422', 1, 2, '192.168.0.148', '192.168.0.148', 138.124236, 136.578723, 137, 2);
