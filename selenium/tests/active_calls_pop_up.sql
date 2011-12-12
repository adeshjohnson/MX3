INSERT INTO `users` (`id`, `username`, `password`, `usertype`, `logged`, `first_name`     , `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated` , `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `c2c_service_active`, `temporary_id`, `send_invoice_types`, `call_limit`, `c2c_call_price`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at` , `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`) VALUES
                    (16 ,'user_resellers2' ,'e10f43b9','user'     ,0        ,'User'       ,'Resellers 2',3                    ,1                        ,0         ,0                ,1        ,1          ,0         ,3           ,0                 ,'2010-01-01 00:00:00',0                  ,0                          ,1                   ,11                  ,-1       ,NULL       ,NULL               ,NULL             ,NULL       ,NULL               ,NULL         ,18            ,NULL         ,NULL                ,3          ,0        ,0                   ,'2011-01-01 00:00:00'    ,NULL         ,0                    ,NULL           ,1                    ,0            ,NULL             ,NULL            ,NULL         ,0                    ,0                  ,0                   ,1                  ,0       ,0       ,0       ,0       ,'2021-01-01',15                     ,0                       ,0                   ,0                          ,NULL               ,100                   ,0                      ,0                       ,0                    ,0        ,1                    ,0);
INSERT INTO `devices` (`id`, `name`, `host`  , `secret`     , `context` , `ipaddr` , `port`, `regseconds`, `accountcode`, `callerid`    , `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`   , `deny`          , `permit`        , `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`             , `istrunk`, `cid_from_dids`, `pin`  , `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`) VALUES 
                      ( 11 ,'220'  ,'dynamic','220'         ,'mor_local','0.0.0.0' ,0      ,1175892667   ,3             ,'\"220\" <220>','220'       ,0                  ,'220'      ,'SIP'         ,16        ,0                ,1                  ,0            ,0        ,'no'       ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes' ,'yes'     ,''            ,'no'          ,NULL             ,'rfc2833'  ,NULL        ,NULL          ,NULL       ,NULL         ,'no'        ,'no'       ,'no'       ,'never'          ,'no'           ,1             ,'Test Device for cs_user 1',0         ,0               ,NULL    ,0              ,0           ,60                     ,60                   ,'no'          ,NULL        ,0     ,'no'           ,60        ,0                     ,NULL           ,0                       ,0            ,'yes'       ,'yes'           ,0         ,0            ,0                    ,0                ,NULL),
                      ( 12 ,'1001' ,'dynamic','k9yyg9ercctj','mor_local',''        , 5060  ,          0  ,           8  , NULL          ,'1001'      ,               0   ,'1001'     ,'SIP'         ,       0  ,               0 ,                 1 ,           0 ,       0 ,'no'       ,'all'      ,'alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes' ,'1000'    , NULL         ,'no'          ,              0  ,'rfc2833'  ,NULL        ,NULL          ,NULL       ,NULL         ,'no'        ,'no'       , NULL      ,'no'             ,'no'           ,           1  ,'SIP_device'               ,        0 ,              0 ,'071506',             0 ,          0 ,                    60 ,                  60 ,'no'          , NULL       ,    0 ,'no'           ,       60 ,                    0 ,         NULL  ,                      0 ,           0 ,'yes'       ,'yes'           ,       0  ,       NULL  ,                   0 ,              0  , '' ),
                      ( 13 ,'1003' ,'dynamic','ce22976780zs','mor_local',''        , 4569  ,          0  ,           9  , NULL          ,'1003'      ,               0   ,'1003'     ,'IAX2'        ,       3  ,               0 ,                 1 ,           0 ,       0 ,'no'       ,'all'      ,'alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes' ,'1000'    , NULL         ,'no'          ,              0  ,'rfc2833'  ,NULL        ,NULL          ,NULL       ,NULL         ,'no'        ,'no'       , NULL      ,'no'             ,'no'           ,           1  ,'IAX2_device'              ,        0 ,              0 ,'355014',             0 ,          0 ,                    60 ,                  60 ,'no'          , NULL       ,    0 ,'no'           ,       60 ,                    0 ,         NULL  ,                      0 ,           0 ,'yes'       ,'yes'           ,       0  ,       NULL  ,                   0 ,              0  ,  ''),
                      ( 14 ,'1004' ,'0.0.0.0',''            ,'mor_local','0.0.0.0' , 1720  ,          0  ,          10  , NULL          ,'1004'      ,               0   ,'1004'     ,'H323'        ,       2  ,               0 ,                 1 ,           0 ,       0 ,'no'       ,'all'      ,'alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes' ,'no'      , NULL         ,'no'          ,              0  ,'rfc2833'  ,NULL        ,NULL          ,NULL       ,NULL         ,'no'        ,'no'       , NULL      ,'no'             ,'no'           ,           1  ,'H323_device'              ,        0 ,              0 ,'132372',             0 ,          0 ,                    60 ,                  60 ,'no'          , NULL       ,    0 ,'no'           ,       60 ,                    0 ,         NULL  ,                      0 ,           0 ,'yes'       ,'yes'           ,       0  ,       NULL  ,                   0 ,              0  , '' ),
                      ( 15 ,'1005' ,'dynamic','41xy4wdnp6ds','mor_local','0.0.0.0' ,    0  ,          0  ,          11  , NULL          ,'1005'      ,               0   ,'1005'     ,'Virtual'     ,       3  ,               0 ,                 1 ,           0 ,       0 ,'no'       ,'all'      ,'alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes' ,'no'      , NULL         ,'no'          ,              0  ,'rfc2833'  ,NULL        ,NULL          ,NULL       ,NULL         ,'no'        ,'no'       , NULL      ,'no'             ,'no'           ,           1  ,'Virtual_device'           ,        0 ,              0 ,'917293',             0 ,          0 ,                    60 ,                  60 ,'no'          , NULL       ,    0 ,'no'           ,       60 ,                    0 ,         NULL  ,                      0 ,        NULL ,'yes'       ,'yes'           ,       0  ,       NULL  ,                   0 ,              0  ,  ''),
                      ( 16 ,'1006' ,'dynamic','6unwansdvvhg','mor_local','0.0.0.0' ,    0  ,          0  ,          12  , NULL          ,'1006'      ,               0   ,'1006'     ,'FAX'         ,       4  ,               0 ,                 1 ,           0 ,       0 ,'no'       ,'all'      ,'alaw'     ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes' ,'no'      , NULL         ,'no'          ,              0  ,'rfc2833'  ,NULL        ,NULL          ,NULL       ,NULL         ,'no'        ,'no'       , NULL      ,'no'             ,'no'           ,           1  ,'FAX_device'               ,        0 ,              0 ,'370452',             0 ,          0 ,                    60 ,                  60 ,'no'          , NULL       ,    0 ,'no'           ,       60 ,                    0 ,         NULL  ,                      0 ,           0 ,'yes'       ,'yes'           ,       0  ,       NULL  ,                   0 ,              0  , '' ),
                      ( 17 ,'1012' ,'dynamic','azvtf0hmybx6','mor_local',''        ,    0  ,          0  ,          18  , NULL          ,'1012'      ,               0   ,'1012'     ,'ZAP'         ,       5  ,               0 ,                 1 ,           0 ,       0 ,'no'       ,'all'      ,'alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes' ,'1000'    , NULL         ,'no'          ,              2  ,'rfc2833'  ,NULL        ,NULL          ,''         ,''           ,'no'        ,'no'       , ''        ,'no'             ,'no'           ,           1  ,'Zap_device'               ,        0 ,              0 ,'430540',             0 ,          0 ,                    60 ,                  60 ,'no'          , NULL       ,    0 ,'no'           ,       60 ,                    0 ,         NULL  ,                      0 ,           0 ,'yes'       ,'yes'           ,       0  ,       NULL  ,                   0 ,              0  ,  ''),
                      ( 18 ,'1013' ,'dynamic','4tj0b5e9rchb','mor_local',''        ,    0  ,          0  ,          19  , NULL          ,'1013'      ,               0   ,'1013'     ,'Skype'       ,       2  ,               0 ,                 1 ,           0 ,       0 ,'no'       ,'all'      ,'alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes' ,'1000'    , NULL         ,'no'          ,              0  ,'rfc2833'  ,NULL        ,NULL          ,''         ,''           ,'no'        ,'no'       , ''        ,'no'             ,'no'           ,           1  ,'Skype_device'             ,        0 ,              0 ,'533562',             0 ,          0 ,                    60 ,                  60 ,'no'          , NULL       ,    0 ,'no'           ,       60 ,                    0 ,         NULL  ,                      0 ,           0 ,'yes'       ,'yes'           ,       0  ,       NULL  ,                   0 ,              0  , '' );
INSERT INTO `activecalls` 
 (`id`, `server_id`, `uniqueid`,         `start_time`                        , `answer_time`                     ,`transfer_time`, `src`,         `dst`,       `src_device_id`, `dst_device_id`, `channel`,                   `dstchannel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`) VALUES
 (10,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 50 SECOND),DATE_SUB(NOW(), INTERVAL 40 SECOND),          NULL, '306984327348','63727007888',7,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              1,        5,          3,          '63727007887'),
 (11,    2,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 40 SECOND),DATE_SUB(NOW(), INTERVAL 30 SECOND),          NULL, '306984327349','63727007889',11,             0,               'SIP/10.219.62.200-c40daf10','',           NULL,     2,              1,       16,          3,          '63727007886'),
 (12,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 50 SECOND),DATE_SUB(NOW(), INTERVAL 40 SECOND),          NULL, '306984327348','63727007888',12,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              1,        0,          0,          '63727007887'),
 (13,    2,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 40 SECOND),DATE_SUB(NOW(), INTERVAL 30 SECOND),          NULL, '306984327349','63727007889',13,             0,               'SIP/10.219.62.200-c40daf10','',           NULL,     2,              1,       3,          0,          '63727007886'),
 (14,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 50 SECOND),DATE_SUB(NOW(), INTERVAL 40 SECOND),          NULL, '306984327348','63727007888',14,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              1,        2,          0,          '63727007887'),
 (15,    2,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 40 SECOND),DATE_SUB(NOW(), INTERVAL 30 SECOND),          NULL, '306984327349','63727007889',15,             0,               'SIP/10.219.62.200-c40daf10','',           NULL,     2,              1,       3,          0,          '63727007886'),
 (16,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 50 SECOND),DATE_SUB(NOW(), INTERVAL 40 SECOND),          NULL, '306984327348','63727007888',16,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              1,        4,          0,          '63727007887'),
 (17,    2,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 40 SECOND),DATE_SUB(NOW(), INTERVAL 30 SECOND),          NULL, '306984327349','63727007889',17,             0,               'SIP/10.219.62.200-c40daf10','',           NULL,     2,              1,       5,          3,          '63727007886'),
 (18,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 50 SECOND),DATE_SUB(NOW(), INTERVAL 40 SECOND),          NULL, '306984327348','63727007888',18,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              1,        2,          0,          '63727007887'),
 (19,    2,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 40 SECOND),DATE_SUB(NOW(), INTERVAL 30 SECOND),          NULL, '306984327349','63727007889',3,             0,               'SIP/10.219.62.200-c40daf10','',           NULL,     2,              1,       2,          0,          '63727007886');

