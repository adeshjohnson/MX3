INSERT INTO `groups` (`id`, `name`, `grouptype`) VALUES  
(1, 'All users', 'simple'),
(2, 'Test_shop', 'callshop'); 

INSERT INTO `usergroups` (`id`, `user_id`, `group_id`, `gusertype`) VALUES 
	 	(1, 0, 1, 'manager'), 
	 	(2, 1, 1, 'user'), 
	 	(3, 2, 1, 'user'), 
	 	(4, 3, 1, 'user');


