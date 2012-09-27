INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`, `balance`) VALUES
(2, 'Test provider 2', 'SIP', '', 'Test provider 2', 'please_change', '0.0.0.0', '5060', 1, 1, 1, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 0.000000000000000),
(3, 'Test provider 3', 'SIP', '', 'Teste provider 3', 'please_change', '0.0.0.0', '5060', 1, 1, 1, 0, 0, '', '', 9, 0, 60, 0, 0, 0, 0, '', 0, '', 0, 0, 0, 0, 0.000000000000000),
(4, 'Common use provider', 'SIP', '', 'Common use provider', 'please_change', '0.0.0.0', '5060', 1, 1, 1, 0, 0, '', '', 10, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 0.000000000000000),
(5, 'Common use provider 2', 'SIP', '', 'Common use provider 2', 'please_change', '0.0.0.0', '5060', 1, 1, 1, 0, 0, '', '', 11, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 0.000000000000000),
(6, 'Reseller Test Provider', 'SIP', '', 'Reseller Test Provider', 'please_change', '0.0.0.0', '5060', 1, 1, 6, 0, 0, '', '', 12, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0, 0.000000000000000),
(7, 'Reseller Test Provider 2', 'SIP', '', 'Reseller Test Provider 2', 'please_change', '0.0.0.0', '5060', 1, 1, 6, 0, 0, '', '', 13, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0, 0.000000000000000);
update users set own_providers=1 where id=3;
update providers set common_use=1 where id in (6,7);
INSERT INTO `common_use_providers`(`id`, `provider_id`, `reseller_id`,`tariff_id`) VALUES
(11,4,3,1),
(12,1,3,1),
(13,5,3,1);
