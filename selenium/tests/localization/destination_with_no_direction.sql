INSERT INTO `destinations` (id, prefix, direction_code, subcode, name, city,  state, lata, tier, ocn, destinationgroup_id)
VALUES(  222222222 , 22222222     , 'TST '           , 'FIX'     , 'Afghanistan proper' ,   ''   ,   ''    , ''     ,    0 ,    ''  , ''  );
INSERT INTO `rates` (id , tariff_id , destination_id , destinationgroup_id )
VALUES (222222222,222222222, 222222222, '');
INSERT INTO `sms_messages`
(`id`,             `sending_date`,       `status_code`, `provider_id`, `provider_rate`, `provider_price`, `user_id`, `user_rate`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_price`, `prefix`, `number`,      `clickatell_message_id`) VALUES
(222222,    '2010-01-01 10:54:23', '0',                   NULL,          0,              0,                0,         0,           10,           0,             0,               0,        22222222        ,     '+37061111111','1234');

