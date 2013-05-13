# Admin user calls through provider
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =33 LIMIT 1 ;
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =39 LIMIT 1 ;
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =45 LIMIT 1 ;
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =48 LIMIT 1 ;
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =54 LIMIT 1 ;
# Reseller user calls through provider
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =30 LIMIT 1 ;
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =32 LIMIT 1 ;
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =36 LIMIT 1 ;
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =43 LIMIT 1 ;
UPDATE `calls` SET `user_price` = 0 WHERE `calls`.`id` =52 LIMIT 1 ;
# Reseller user calls through DID
UPDATE `calls` SET `did_inc_price` = 0 WHERE `calls`.`id` =30 LIMIT 1 ;
UPDATE `calls` SET `did_inc_price` = 0 WHERE `calls`.`id` =32 LIMIT 1 ;
UPDATE `calls` SET `did_inc_price` = 0 WHERE `calls`.`id` =36 LIMIT 1 ;
UPDATE `calls` SET `did_inc_price` = 0 WHERE `calls`.`id` =43 LIMIT 1 ;
UPDATE `calls` SET `did_inc_price` = 0 WHERE `calls`.`id` =52 LIMIT 1 ;
