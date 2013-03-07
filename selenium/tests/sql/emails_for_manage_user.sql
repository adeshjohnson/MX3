INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES
(15, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'test_email@email.com'),
(16, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'test_email@email.com');

UPDATE `users` set address_id=15 where id=4;
UPDATE `users` set address_id=16 where id=5;
