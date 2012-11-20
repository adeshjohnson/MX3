INSERT INTO `users` (`id`, `username`, `password`, `usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `c2c_service_active`, `temporary_id`, `send_invoice_types`, `call_limit`, `c2c_call_price`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`, `hide_destination_end`, `warning_email_hour`, `warning_balance_call`, `warning_balance_sound_file_id`, `own_providers`, `ignore_global_monitorings`, `currency_id`, `quickforwards_rule_id`, `spy_device_id`, `time_zone`, `minimal_charge`, `minimal_charge_start_at`, `webphone_allow_use`, `webphone_device_id`, `responsible_accountant_id`) VALUES
(15, 'hidden_reseller', 'f51bab373bf1f114ec15d24268a1f56bb49f1ccd', 'reseller', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 1, 1, 0, 4, 0.000000000000000, NULL, 0, 0, 1, 0, -1.000000000000000, '', '0000000004', '2012-11-19', '', 123, '', 0.000000000000000, 5, '', 0, 1, 0, '2000-01-01 00:00:00', 'jrg9dsrwzz', 0, NULL, 0, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 2, 1, 12, -1, -1, 0, 0, 0, 0, 1, 0, 0, 'UTC', 0, NULL, 0, 0, -1),
(13, 'blocked_reseller', 'f51bab373bf1f114ec15d24268a1f56bb49f1ccd', 'reseller', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 1, 1, 1, 4, 0.000000000000000, NULL, 0, 0, 1, 0, -1.000000000000000, '', '0000000005', '2012-11-19', '', 123, '', 0.000000000000000, 6, '', 0, 0, 0, '2000-01-01 00:00:00', '1p5geg610d', 0, NULL, 0, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 3, 1, 12, -1, -1, 0, 0, 0, 0, 1, 0, 0, 'UTC', 0, NULL, 0, 0, -1),
(14, 'hidden_and_blocked_reseller', 'f51bab373bf1f114ec15d24268a1f56bb49f1ccd', 'reseller', 0, '', '', 3.000000000000000, 0, 0.000000000000000, 0.000000000000000, 1, 1, 1, 4, 0.000000000000000, NULL, 0, 0, 1, 0, -1.000000000000000, '', '0000000006', '2012-11-19', '', 123, '', 0.000000000000000, 7, '', 0, 1, 0, '2000-01-01 00:00:00', '0k09cb7txv', 0, NULL, 0, 0, 0.000000000000000, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 4, 1, 12, -1, -1, 0, 0, 0, 0, 1, 0, 0, 'UTC', 0, NULL, 0, 0, -1);

INSERT INTO `acc_groups` (`id`, `name`, `only_view`, `group_type`, `description`) VALUES
(1, '!!!!', 0, 'accountant', '');

INSERT INTO `acc_group_rights` (`id`, `acc_group_id`, `acc_right_id`, `value`) VALUES
(1, 1, 1, 2),
(2, 1, 2, 2),
(3, 1, 3, 2),
(4, 1, 4, 2),
(5, 1, 5, 2),
(6, 1, 6, 2),
(7, 1, 7, 2),
(8, 1, 8, 2),
(9, 1, 9, 2),
(10, 1, 10, 2),
(11, 1, 11, 2),
(12, 1, 12, 2),
(13, 1, 13, 2),
(14, 1, 14, 2),
(15, 1, 15, 2),
(16, 1, 16, 2),
(17, 1, 17, 2),
(18, 1, 18, 2),
(19, 1, 19, 2),
(20, 1, 20, 2),
(21, 1, 21, 2),
(22, 1, 22, 0),
(23, 1, 23, 2),
(24, 1, 24, 2),
(25, 1, 25, 2),
(26, 1, 26, 2),
(27, 1, 27, 2),
(28, 1, 28, 2),
(29, 1, 29, 2),
(30, 1, 30, 0),
(31, 1, 36, 0);


