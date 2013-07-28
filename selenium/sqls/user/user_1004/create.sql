# Paprastas useris, pvz., subscriptionų testavimui (kai reikia tikslios registracijos datos)
INSERT INTO `actions` (`user_id`, `date`, `action`, `data`, `data2`, `processed`, `target_type`, `target_id`, `data3`, `data4`) VALUES
(0, '2013-07-28 09:45:11', 'user_created', '', '', 0, 'user', 1004, NULL, NULL);

INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES
(1004, 1, '', '', '', '', '', '', '', '', NULL);

INSERT INTO `devicegroups` (`user_id`, `address_id`, `name`, `added`, `primary`) VALUES
(1004, 1004, 'primary', '2013-07-28 09:40:22', 1);

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(1004, 0, 0, 0, 0, 'TAX', '', '', '', 'TAX', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1);

INSERT INTO `users` (`id`, `username`, `password`, `usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `temporary_id`, `send_invoice_types`, `call_limit`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`, `hide_destination_end`, `warning_email_hour`, `warning_balance_call`, `warning_balance_sound_file_id`, `own_providers`, `ignore_global_monitorings`, `currency_id`, `quickforwards_rule_id`, `spy_device_id`, `time_zone`, `minimal_charge`, `minimal_charge_start_at`, `webphone_allow_use`, `webphone_device_id`, `responsible_accountant_id`, `blacklist_enabled`, `blacklist_lcr`, `routing_threshold`) VALUES
(1004, 'testuser', 'bc51a83eea09846dc02407dd0979968912a207a9', 'user', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 1, 1, 0, 4, 0.000000000000000, NULL, 0, 0, 1, 0, -1.000000000000000, '', '0000000004', '2013-07-28', '', 123, '', 0.000000000000000, 1004, '', 0, 0, 0, '2000-01-01 00:00:00', 'pymc6uq980', NULL, 0, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 1004, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 'UTC', 0, NULL, 0, 0, -1, 'global', -1, -1);


