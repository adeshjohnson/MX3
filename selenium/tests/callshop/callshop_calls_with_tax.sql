/* 3 cs_invoice and one outgoing active call for users */
INSERT INTO `activecalls`
  (`id`, `server_id`, `uniqueid`,         `start_time`, `answer_time`, `transfer_time`, `src`,         `dst`,       `src_device_id`, `dst_device_id`, `channel`,                   `dstchannel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`) VALUES
  (24  ,    1       ,'1249296551.111096',NOW(),        NOW(),          NULL,            '306984327342','63727007889', 11,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     1,              0,       17,         0,          '63727007889'),
  (25  ,    1       ,'1249296551.111096',NOW(),        NOW(),          NULL,            '306984327343','63727007883', 12,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     1,              0,       18,         0,          '63727007889'),
  (26  ,    1       ,'1249296551.111096',NOW(),        NOW(),          NULL,            '306984327344','63727007884', 13,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     1,              0,       19,         0,          '63727007889');
INSERT INTO `cs_invoices` (`id`, `callshop_id`, `user_id`, `state` , `invoice_type`, `balance`, `comment`    , `paid_at`, `updated_at`                     , `created_at`                    ,`tax_id`)VALUES
                          (111   ,  10           , 17       , 'unpaid', 'postpaid'     , 13.00    , 'komentaras1', NULL     , DATE_SUB(NOW() , INTERVAL 1 HOUR), DATE_SUB(NOW(), INTERVAL 1 HOUR),19      );
INSERT INTO `cs_invoices` (`id`, `callshop_id`, `user_id`, `state` , `invoice_type`, `balance`, `comment`    , `paid_at`, `updated_at`                     , `created_at`                    ,`tax_id`)VALUES
                          (211   ,   11         , 18       , 'unpaid', 'postpaid'     , 10.00    , 'komentaras2', NULL     , DATE_SUB(NOW() , INTERVAL 1 HOUR), DATE_SUB(NOW(), INTERVAL 1 HOUR),17      );
INSERT INTO `cs_invoices` (`id`, `callshop_id`, `user_id`, `state` , `invoice_type`, `balance`, `comment`    , `paid_at`, `updated_at`                     , `created_at`                    ,`tax_id`)VALUES
                          (311   ,  12         , 19       , 'unpaid', 'postpaid'     , 15.00    , 'komentaras3', NULL     , DATE_SUB(NOW() , INTERVAL 1 HOUR), DATE_SUB(NOW(), INTERVAL 1 HOUR),18      );
/* call records for stats */
INSERT INTO `calls` (`id`, `calldate`          , `clid`               , `src`       , `dst`       , `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`   , `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`,`partner_billsec`,`partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `peerip`, `recvip`, `sipfrom`, `uri`, `useragent`, `peername`, `t38passthrough`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`)VALUES 
     (211  ,DATE_SUB(NOW(), INTERVAL 30 SECOND),''                    ,'101'        ,'123123'     ,''         ,''        ,''           ,''        ,''         ,40         ,50        ,'ANSWERED'    ,0          ,'2'           ,'1232113379.3',''          ,2               ,0               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,17        ,1           ,1              ,5            ,3             ,0               ,0                  ,4                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,''       ,''       ,''        ,''    ,''          ,''         ,0                ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0);
INSERT INTO `calls` (`id`, `calldate`          , `clid`               , `src`       , `dst`       , `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`   , `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`,`partner_billsec`,`partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `peerip`, `recvip`, `sipfrom`, `uri`, `useragent`, `peername`, `t38passthrough`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`)VALUES 
     (224  ,DATE_SUB(NOW(), INTERVAL 50 SECOND),''                    ,'101'        ,'123123'     ,''         ,''        ,''           ,''        ,''         ,40         ,50        ,'ANSWERED'    ,0          ,'2'           ,'1232113379.3',''          ,2               ,0               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,18        ,1           ,1              ,2            ,3             ,0               ,0                  ,4                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,''       ,''       ,''        ,''    ,''          ,''         ,0                ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0);
INSERT INTO `calls` (`id`, `calldate`          , `clid`               , `src`       , `dst`       , `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`   , `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`,`partner_billsec`,`partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `peerip`, `recvip`, `sipfrom`, `uri`, `useragent`, `peername`, `t38passthrough`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`)VALUES 
     (214  ,DATE_SUB(NOW(), INTERVAL 40 SECOND),''                    ,'101'        ,'123123'     ,''         ,''        ,''           ,''        ,''         ,40         ,50        ,'ANSWERED'    ,0          ,'2'           ,'1232113379.3',''          ,2               ,0               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,19        ,1           ,1              ,4            ,3             ,0               ,0                  ,4                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,''       ,''       ,''        ,''    ,''          ,''         ,0                ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0);

