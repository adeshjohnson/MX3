INSERT INTO `activecalls`
  (`id`, `server_id`, `uniqueid`,         `start_time`, `answer_time`, `transfer_time`, `src`,         `dst`,       `src_device_id`, `dst_device_id`, `channel`,                   `dstchannel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`) VALUES
  (24  ,    1,      '1249296551.111096',   NOW(),        NOW(),          NULL,        '555333327342','55533307889', 11,              0,               'SIP/10.219.62.200-c40daf10','',           '555333',     1,              0,       9,         0,          '55533307889');

INSERT INTO `destinations` (`id`,`prefix`,`direction_code`,`subcode`,`name`     ,`city`,`state`,`lata`,`tier`,`ocn`,`destinationgroup_id`)
VALUES                    (200431, 555333 ,''             ,'MOB '   , 'testini_s' , NULL , NULL  , NULL , NULL , NULL,                   0);

