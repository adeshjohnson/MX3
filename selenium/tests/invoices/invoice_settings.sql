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
delete from `conflines` where id=130;
delete from `conflines` where id=131;
delete from `conflines` where id=184;
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
delete from `conflines` where id=209;
delete from `conflines` where id=240;
delete from `conflines` where id=240;
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(1800, 'Invoice_Number_Length', '11', 0, NULL),
(1900, 'Invoice_Number_Type', '1', 0, NULL),
(3700, 'Tariff_for_registered_users', NULL, 0, NULL),
(3800, 'LCR_for_registered_users', NULL, 0, NULL),
(4200, 'Default_CID_Name', NULL, 0, NULL),
(4300, 'Default_CID_Number', NULL, 0, NULL),
(6200, 'Email_Sending_Enabled', NULL, 0, NULL),
(1840, 'Tax_1', 'First-tax', 0, '1'),
(1850, 'Tax_2', 'Second-tax', 0, '1'),
(1860, 'Tax_3', 'Third-tax', 0, '1'),
(1870, 'Tax_4', 'Forth-tax', 0, '1'),
(1808, 'Total_tax_name', 'Total_tax_name', 0, NULL),
(1890, 'Banned_CLIs_default_IVR_id', '0', 0, NULL),
(1900, 'Tax_1_Value', '10.0', 0, NULL),
(1910, 'Tax_2_Value', '10.0', 0, NULL),
(1920, 'Tax_3_Value', '20.0', 0, NULL),
(1930, 'Tax_4_Value', '30.0', 0, NULL);
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(2005, 'Prepaid_Invoice_Number_Start', 'INV', 0, NULL),
(2006, 'Prepaid_Invoice_Number_Length', '11', 0, NULL),
(2007, 'Prepaid_Invoice_Number_Type', '1', 0, NULL),
(2009, 'Prepaid_Invoice_Show_Calls_In_Detailed', '1', 0, NULL),
(2400, 'Tax_1', 'First-tax', 0, '1'),
(2901, 'Registration_allow_vat_blank', '0', 0, NULL),
(2902, 'Invoice_To_Pay_Line', '', 0, NULL),
(2903, 'Invoice_Add_Average_rate', '0', 0, NULL),
(2094, 'Invoice_Show_Time_in_Minutes', '0', 0, NULL),
(2905, 'Show_recordings_with_zero_billsec', '0', 0, NULL),
(2906, 'Invoice_Short_File_Name', '0', 0, NULL),
(2907, 'Invoice_user_billsec_show', '0', 0, NULL),
(2908, 'Invoice_show_additional_details_on_separate_page', '0', 0, ''),
(2909, 'Prepaid_Invoice_To_Pay_Line', '', 0, NULL),
(3000, 'Prepaid_Invoice_Add_Average_rate', '0', 0, NULL),
(3010, 'Prepaid_Invoice_Show_Time_in_Minutes', '0', 0, NULL);
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(3020, 'Prepaid_Invoice_Short_File_Name', '0', 0, NULL),
(3030, 'Prepaid_Invoice_user_billsec_show', '0', 0, NULL),
(3040, 'Prepaid_Invoice_show_additional_details_on_separate_page', '0', 0, ''),
(3005, 'Invoice_allow_recalculate_after_send', '0', 0, NULL),
(3060, 'Tax_compound', '1', 0, NULL),
(3070, 'Date_format', '%Y-%m-%d %H:%M:%S', 0, NULL),
(3000, 'Disallow_prepaid_user_balance_drop_below_zero', '0', 0, NULL),
(3009, 'Hide_non_completed_payments_for_user', '0', 0, NULL),
(3100, 'Disallow_Email_Editing', '', 0, NULL),
(3110, 'System_time_zone_daylight_savings', '0', 0, NULL),
(3120, 'Logout_link', '', 0, NULL),
(3130, 'Devices_Check_Rate', '', 0, NULL),
(3140, 'Allow_short_passwords_in_devices', '0', 0, NULL),
(3150, 'Show_zero_rates_in_LCR_tariff_export', '0', 0, NULL),
(3160, 'Show_Active_Calls_for_Users', '', 0, NULL),
(3170, 'Active_Calls_Show_Server', '', 0, NULL),
(3180, 'Show_Advanced_Rates_For_Users', '0', 0, NULL),
(3190, 'Show_advanced_Provider_settings', '0', 0, NULL),
(3200, 'Show_advanced_Device_settings', '0', 0, NULL),
(3210, 'Hide_payment_options_for_postpaid_users', '0', 0, NULL),
(3220, 'Hide_quick_stats', '0', 0, NULL);
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(3230, 'Hide_HELP_banner', '0', 0, NULL),
(3240, 'Hide_Iwantto', '0', 0, NULL),
(3250, 'Hide_Manual_Link', '0', 0, NULL),
(3260, 'Hide_Device_Passwords_For_Users', '0', 0, NULL),
(3270, 'Show_only_main_page', '0', 0, NULL),
(3280, 'Show_forgot_password', '0', 0, NULL),
(3290, 'Hide_recordings_for_all_users', '0', 0, NULL),
(3300, 'API_Login_Redirect_to_Main', '0', 0, NULL),
(3310, 'API_Allow_registration_ower_API', '0', 0, NULL),
(3320, 'API_Disable_hash_checking', '0', 0, NULL),
(3330, 'CSV_File_size', '0', 0, NULL),
(3340, 'Play_IVR_for_200_HGC', '0', 0, NULL);
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(3350, 'IVR_for_200_HGC', '0', 0, NULL),
(3360, 'Registration_Agreement', '0', 0, NULL),
(3370, 'Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users', '0', 0, NULL),
(3380, 'Tell_Balance', '0', 0, NULL),
(3390, 'Tell_Time', '0', 0, NULL),
(3400, 'API_Allow_payments_ower_API', '0', 0, NULL),
(3410, 'API_payment_confirmation', '0', 0, NULL),
(3420, 'Hide_Destination_End', '0', 0, NULL),
(4130, 'Prepaid_Invoice_Number_Start', 'INV', 0, NULL),
(4140, 'Prepaid_Invoice_Number_Length', '11', 0, NULL),
(4150, 'Prepaid_Invoice_Number_Type', '1', 0, NULL),
(4160, 'Prepaid_Invoice_To_Pay_Line', '', 0, NULL),
(4170, 'Prepaid_Invoice_Add_Average_rate', '0', 0, NULL),
(4180, 'Prepaid_Invoice_Show_Time_in_Minutes', '0', 0, NULL),
(4190, 'Prepaid_Invoice_Short_File_Name', '0', 0, NULL),
(4200, 'Prepaid_Invoice_user_billsec_show', '0', 0, NULL),
(4210, 'Prepaid_Invoice_show_additional_details_on_separate_page', '0', 0, ''),
(4220, 'Invoice_allow_recalculate_after_send', '0', 0, NULL),
(6330, 'Prepaid_Invoice_Number_Start', 'INV', 0, NULL),
(6340, 'Prepaid_Invoice_Number_Length', '11', 0, NULL),
(6350, 'Prepaid_Invoice_Number_Type', '1', 0, NULL);

UPDATE `devices` set location_id=2 where id=7;

INSERT INTO `locationrules` (`id`, `location_id`, `name`, `enabled`, `cut`, `add`, `minlen`, `maxlen`, `lr_type`, `lcr_id`, `tariff_id`, `did_id`, `device_id`) VALUES
(2, 2, 'Int. prefix', 1, '00', '', 10, 20, 'dst', NULL, NULL, NULL, NULL);

INSERT INTO `locations` (`id`, `name`, `user_id`) VALUES
(2, 'Default location', 3);

DELETE FROM `subscriptions`;
INSERT INTO `subscriptions` (`id`, `service_id`, `user_id`, `device_id`, `activation_start`, `activation_end`, `added`, `memo`) VALUES
(1, 1, 2, NULL, '2011-01-01 00:00:00', '2013-01-31 00:00:00', '2009-04-22 09:25:00', 'Test_preriodic_service_memo');

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(2, 0, 1, 1, 1, 'First-tax', 'Second-tax', 'Third-tax', 'Forth-tax', 'Total_tax_name', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1),
(3, 0, 1, 1, 1, 'First-tax', 'Second-tax', 'Third-tax', 'Forth-tax', 'Total_tax_name', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1),
(4, 0, 1, 1, 1, 'First-tax', 'Second-tax', 'Third-tax', 'Forth-tax', 'Total_tax_name', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1),
(5, 0, 1, 1, 1, 'First-tax', 'Second-tax', 'Third-tax', 'Forth-tax', 'Total_tax_name', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1);

