INSERT INTO `actions` (`id`, `user_id`, `date`, `action`, `data`, `data2`, `processed`, `target_type`, `target_id`, `data3`, `data4`) VALUES
(5002, 0, '2013-05-22 16:27:32', 'Confline changed', '1', '4002', 0, 'confline', 278, NULL, 'Resellers_server_id');

INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(5001, 'Resellers_server_id', '4002', 0, NULL);

INSERT INTO `server_devices` (`id`, `device_id`, `server_id`) VALUES
(20, 2041, 15),
(21, 2342, 16);
