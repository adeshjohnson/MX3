INSERT INTO `acc_groups`(`id`,`name`                  ,`group_type`) VALUES
                        ( 11 ,'Accountant_permissions','accountant'),
                        ( 12 ,'Reseller_Permissions'  ,'reseller');
INSERT INTO `acc_group_rights` (`id`, `acc_group_id`, `acc_right_id`, `value`) VALUES
(1, 11, 1, 0),
(2, 11, 2, 0),
(3, 11, 3, 0),
(4, 11, 4, 0),
(5, 11, 5, 0),
(6, 11, 6, 0),
(7, 11, 7, 0),
(8, 11, 8, 0),
(9, 11, 9, 0),
(10, 11, 10, 0),
(11, 11, 11, 0),
(12, 11, 12, 0),
(13, 11, 13, 0),
(14, 11, 14, 0),
(15, 11, 15, 0),
(16, 11, 16, 0),
(17, 11, 17, 0),
(18, 11, 18, 0),
(19, 11, 19, 0),
(20, 11, 20, 0),
(21, 11, 21, 0),
(22, 11, 22, 0),
(23, 11, 23, 0),
(24, 11, 24, 0),
(25, 11, 25, 2),
(26, 11, 26, 0),
(27, 11, 27, 0),
(28, 11, 28, 2),
(29, 11, 29, 0),
(30, 11, 30, 0),
(31, 11, 36, 0);

delete from `conflines` where id=18;
delete from `conflines` where id=19;
delete from `conflines` where id=37;
delete from `conflines` where id=38;
delete from `conflines` where id=42;
delete from `conflines` where id=43;
delete from `conflines` where id=62;
delete from `conflines` where id=185;
delete from `conflines` where id=186;
delete from `conflines` where id=187;
delete from `conflines` where id=188;
delete from `conflines` where id=189;
delete from `conflines` where id=190;
delete from `conflines` where id=191;
delete from `conflines` where id=192;
delete from `conflines` where id=193;
delete from `conflines` where id=205;
delete from `conflines` where id=206;
delete from `conflines` where id=207;
delete from `conflines` where id=240;
delete from `conflines` where id=240;
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(18, 'Invoice_Number_Length', '11', 0, NULL),
(19, 'Invoice_Number_Type', '1', 0, NULL),
(37, 'Tariff_for_registered_users', NULL, 0, NULL),
(38, 'LCR_for_registered_users', NULL, 0, NULL),
(42, 'Default_CID_Name', NULL, 0, NULL),
(43, 'Default_CID_Number', NULL, 0, NULL),
(62, 'Email_Sending_Enabled', NULL, 0, NULL),
(185, 'Tax_2', 'Second-tax', 0, '1'),
(186, 'Tax_3', 'Third-tax', 0, '1'),
(187, 'Tax_4', 'Forth-tax', 0, '1'),
(188, 'Total_tax_name', 'Total_tax_name', 0, NULL),
(189, 'Banned_CLIs_default_IVR_id', '0', 0, NULL),
(190, 'Tax_1_Value', '10.0', 0, NULL),
(191, 'Tax_2_Value', '10.0', 0, NULL),
(192, 'Tax_3_Value', '20.0', 0, NULL),
(193, 'Tax_4_Value', '30.0', 0, NULL),
(205, 'Prepaid_Invoice_Number_Start', 'INV', 0, NULL),
(206, 'Prepaid_Invoice_Number_Length', '11', 0, NULL),
(207, 'Prepaid_Invoice_Number_Type', '1', 0, NULL),
(240, 'Tax_1', 'First-tax', 0, '1'),
(284, 'Hide_registration_link', '', 0, NULL),
(285, 'reCAPTCHA_enabled', '0', 0, NULL),
(286, 'ReCAPTCHA_public_key', '', 0, NULL),
(287, 'ReCAPTCHA_private_key', '', 0, NULL),
(288, 'Allow_registration_username_passwords_in_devices', '0', 0, NULL),
(289, 'Active_calls_show_did', '0', 0, NULL),
(290, 'Registration_Enable_VAT_checking', '0', 0, NULL),
(291, 'Registration_allow_vat_blank', '0', 0, NULL),
(292, 'Invoice_To_Pay_Line', '', 0, NULL),
(293, 'Invoice_Add_Average_rate', '0', 0, NULL),
(294, 'Invoice_Show_Time_in_Minutes', '0', 0, NULL),
(295, 'Show_recordings_with_zero_billsec', '0', 0, NULL),
(296, 'Invoice_Short_File_Name', '0', 0, NULL),
(297, 'Invoice_user_billsec_show', '0', 0, NULL),
(298, 'Invoice_show_additional_details_on_separate_page', '0', 0, ''),
(299, 'Prepaid_Invoice_To_Pay_Line', '', 0, NULL),
(300, 'Prepaid_Invoice_Add_Average_rate', '0', 0, NULL),
(301, 'Prepaid_Invoice_Show_Time_in_Minutes', '0', 0, NULL),
(302, 'Prepaid_Invoice_Short_File_Name', '0', 0, NULL),
(303, 'Prepaid_Invoice_user_billsec_show', '0', 0, NULL),
(304, 'Prepaid_Invoice_show_additional_details_on_separate_page', '0', 0, ''),
(305, 'Invoice_allow_recalculate_after_send', '0', 0, NULL),
(306, 'Tax_compound', '1', 0, NULL),
(307, 'Date_format', '%Y-%m-%d %H:%M:%S', 0, NULL),
(308, 'Disallow_prepaid_user_balance_drop_below_zero', '0', 0, NULL),
(309, 'Hide_non_completed_payments_for_user', '0', 0, NULL),
(310, 'Disallow_Email_Editing', '', 0, NULL),
(311, 'System_time_zone_daylight_savings', '0', 0, NULL),
(312, 'Logout_link', '', 0, NULL),
(313, 'Devices_Check_Rate', '', 0, NULL),
(314, 'Allow_short_passwords_in_devices', '0', 0, NULL),
(315, 'Show_zero_rates_in_LCR_tariff_export', '0', 0, NULL),
(316, 'Show_Active_Calls_for_Users', '', 0, NULL),
(317, 'Active_Calls_Show_Server', '', 0, NULL),
(318, 'Show_Advanced_Rates_For_Users', '0', 0, NULL),
(319, 'Show_advanced_Provider_settings', '0', 0, NULL),
(320, 'Show_advanced_Device_settings', '0', 0, NULL),
(321, 'Hide_payment_options_for_postpaid_users', '0', 0, NULL),
(322, 'Hide_quick_stats', '0', 0, NULL),
(323, 'Hide_HELP_banner', '0', 0, NULL),
(324, 'Hide_Iwantto', '0', 0, NULL),
(325, 'Hide_Manual_Link', '0', 0, NULL),
(326, 'Hide_Device_Passwords_For_Users', '0', 0, NULL),
(327, 'Show_only_main_page', '0', 0, NULL),
(328, 'Show_forgot_password', '0', 0, NULL),
(329, 'Hide_recordings_for_all_users', '0', 0, NULL),
(330, 'API_Login_Redirect_to_Main', '0', 0, NULL),
(331, 'API_Allow_registration_ower_API', '0', 0, NULL),
(332, 'API_Disable_hash_checking', '0', 0, NULL),
(333, 'CSV_File_size', '0', 0, NULL),
(334, 'Play_IVR_for_200_HGC', '0', 0, NULL),
(335, 'IVR_for_200_HGC', '0', 0, NULL),
(336, 'Registration_Agreement', '0', 0, NULL),
(337, 'Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users', '0', 0, NULL),
(338, 'Tell_Balance', '0', 0, NULL),
(339, 'Tell_Time', '0', 0, NULL),
(340, 'API_Allow_payments_ower_API', '0', 0, NULL),
(341, 'API_payment_confirmation', '0', 0, NULL),
(342, 'Hide_Destination_End', '0', 0, NULL);

UPDATE `devices` set location_id=2 where id=7;

INSERT INTO `locationrules` (`id`, `location_id`, `name`, `enabled`, `cut`, `add`, `minlen`, `maxlen`, `lr_type`, `lcr_id`, `tariff_id`, `did_id`, `device_id`) VALUES
(2, 2, 'Int. prefix', 1, '00', '', 10, 20, 'dst', NULL, NULL, NULL, NULL);

INSERT INTO `locations` (`id`, `name`, `user_id`) VALUES
(2, 'Default location', 3);

DELETE FROM `subscriptions`;
INSERT INTO `subscriptions` (`id`, `service_id`, `user_id`, `device_id`, `activation_start`, `activation_end`, `added`, `memo`) VALUES
(1, 1, 2, NULL, '2011-01-01 00:00:00', '2013-01-31 00:00:00', '2009-04-22 09:25:00', 'Test_preriodic_service_memo');

