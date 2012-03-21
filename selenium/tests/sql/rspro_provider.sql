INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES
(100, 're_prov_tariff', 'provider', 3, 'USD');
INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`) VALUES
(100, 're_prov', 'SIP', '', 're_prov', 'please_change', '0.0.0.0', '5060', 1, 1, 100, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0);
