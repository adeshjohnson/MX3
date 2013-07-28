INSERT INTO `actions` (`id`, `user_id`, `date`, `action`, `data`, `data2`, `processed`, `target_type`, `target_id`, `data3`, `data4`) VALUES
(1302, 3, '2013-07-28 10:31:04', 'user_created', '', '', 0, 'user', 1302, NULL, NULL);

INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES
(1302, 1, '', '', '', '', '', '', '', '', NULL);

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(1302, 0, 0, 0, 0, 'TAX', '', '', '', 'TAX', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1);


INSERT INTO `users` (`id`, `username`, `password`, `usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `temporary_id`, `send_invoice_types`, `call_limit`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`, `hide_destination_end`, `warning_email_hour`, `warning_balance_call`, `warning_balance_sound_file_id`, `own_providers`, `ignore_global_monitorings`, `currency_id`, `quickforwards_rule_id`, `spy_device_id`, `time_zone`, `minimal_charge`, `minimal_charge_start_at`, `webphone_allow_use`, `webphone_device_id`, `responsible_accountant_id`, `blacklist_enabled`, `blacklist_lcr`, `routing_threshold`)
VALUES (1302, 'Sub1', '573b6f9be362595ebf231f5e5879e170eae533c5', 'user', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 1, 1, 0, 3, 0.000000000000000, NULL, 0, 0, 1, 0, -1.000000000000000, '', '0000000004', '2013-07-28', '', 123, '', 0.000000000000000, 1302, '', 3, 0, 0, '2000-01-01 00:00:00', 'k9qdp6eabd', NULL, 0, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, NULL, 0, 0, 0.000000000000000, 0, 1302, 1, 0, -1, -1, 0, 123, 0, 0, 1, 0, 0, 'UTC', 0, NULL, 0, 0, -1, 'global', -1, -1);

INSERT INTO `devicegroups` (`id`, `user_id`, `address_id`, `name`, `added`, `primary`) VALUES
(1302, 1302, 1302, 'primary', '2013-07-28 12:06:34', 1);

