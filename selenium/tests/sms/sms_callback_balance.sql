INSERT INTO users (id, balance, frozen_balance, usertype, postpaid, owner_id, username, password ) 
VALUES 	
	(102, 60000, 3000, 'user', 0, 0, 'Test_user_1', 'd033e22ae348aeb5660fc2140aec35850c4da997'),
	(103, 30000, 1500, 'user', 0, 101, 'Test_user_2', 'd033e22ae348aeb5660fc2140aec35850c4da997'),
	(104, 20000, 2000, 'reseller', 1,0,'Test_reseller_2', 'd033e22ae348aeb5660fc2140aec35850c4da997'),
	(105, 30000, 1000, 'reseller',0, 0,'Test_reseller_3', 'd033e22ae348aeb5660fc2140aec35850c4da997'),
	(106, 10000, 2000, 'user',0, 0, 'Test_user_3', 'd033e22ae348aeb5660fc2140aec35850c4da997'),
	(107, 12000, 1000, 'user',0, 101, 'Test_user_4', 'd033e22ae348aeb5660fc2140aec35850c4da997'),
	(108, 16000, 8000, 'user',1, 0, 'Test_user_5', 'd033e22ae348aeb5660fc2140aec35850c4da997'),
	(109, 30000, 1300, 'user',1, 101, 'Test_user_6', 'd033e22ae348aeb5660fc2140aec35850c4da997');

INSERT INTO users (id, balance, frozen_balance, usertype, postpaid, owner_id, username, password, sms_tariff_id ) 
VALUES 	
       (101, 40000, 2000, 'reseller', 0, 0, 'Test_reseller_1', 'd033e22ae348aeb5660fc2140aec35850c4da997', 2000);
INSERT INTO sms_messages (clickatell_message_id, reseller_price, user_price, user_id)
VALUES 	(1, 12, 10, 101),
	(2, 13, 11, 102),
	(3, 14, 12, 103),
	(4, 15, 13, 104),
	(5, 16, 14, 105),
	(6, 17, 15, 106),
	(7, 18, 16, 107),
	(8, 19, 17, 108),
	(9, 20, 18, 109);
Update users set time_zone = 'Vilnius';
