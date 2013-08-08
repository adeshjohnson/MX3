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
(18, 'Invoice_Number_Length', '11', 0, NULL),
(19, 'Invoice_Number_Type', '1', 0, NULL),
(37, 'Tariff_for_registered_users', NULL, 0, NULL),
(38, 'LCR_for_registered_users', NULL, 0, NULL),
(42, 'Default_CID_Name', NULL, 0, NULL),
(43, 'Default_CID_Number', NULL, 0, NULL),
(62, 'Email_Sending_Enabled', NULL, 0, NULL),
(184, 'Tax_1', 'First-tax', 0, '1'),
(185, 'Tax_2', 'Second-tax', 0, '1'),
(186, 'Tax_3', 'Third-tax', 0, '1'),
(187, 'Tax_4', 'Forth-tax', 0, '1'),
(188, 'Total_tax_name', 'Total_tax_name', 0, NULL),
(189, 'Banned_CLIs_default_IVR_id', '0', 0, NULL),
(190, 'Tax_1_Value', '10.0', 0, NULL),
(191, 'Tax_2_Value', '10.0', 0, NULL),
(192, 'Tax_3_Value', '20.0', 0, NULL),
(193, 'Tax_4_Value', '30.0', 0, NULL);
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(205, 'Prepaid_Invoice_Number_Start', 'INV', 0, NULL),
(206, 'Prepaid_Invoice_Number_Length', '11', 0, NULL),
(209, 'Prepaid_Invoice_Show_Calls_In_Detailed', '1', 0, NULL),
(240, 'Tax_1', 'First-tax', 0, '1'),
(2920, 'Invoice_To_Pay_Line', '', 0, NULL),
(2930, 'Invoice_Add_Average_rate', '0', 0, NULL),
(2940, 'Invoice_Show_Time_in_Minutes', '0', 0, NULL),
(2960, 'Invoice_Short_File_Name', '0', 0, NULL),
(2970, 'Invoice_user_billsec_show', '0', 0, NULL),
(2980, 'Invoice_show_additional_details_on_separate_page', '0', 0, ''),
(2990, 'Prepaid_Invoice_To_Pay_Line', '', 0, NULL),
(3000, 'Prepaid_Invoice_Add_Average_rate', '0', 0, NULL),
(3010, 'Prepaid_Invoice_Show_Time_in_Minutes', '0', 0, NULL);
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(3020, 'Prepaid_Invoice_Short_File_Name', '0', 0, NULL),
(3030, 'Prepaid_Invoice_user_billsec_show', '0', 0, NULL),
(3040, 'Prepaid_Invoice_show_additional_details_on_separate_page', '0', 0, ''),
(3050, 'Invoice_allow_recalculate_after_send', '0', 0, NULL),
(3060, 'Tax_compound', '1', 0, NULL);
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(4130, 'Prepaid_Invoice_Number_Start', 'INV', 0, NULL),
(4140, 'Prepaid_Invoice_Number_Length', '11', 0, NULL),
(4220, 'Invoice_allow_recalculate_after_send', '0', 0, NULL),
(6330, 'Prepaid_Invoice_Number_Start', 'INV', 0, NULL),
(6340, 'Prepaid_Invoice_Number_Length', '11', 0, NULL);
UPDATE `conflines` SET `value`='1' WHERE name='Prepaid_Invoice_Number_Type';

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

