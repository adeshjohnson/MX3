INSERT INTO `conflines` (`name`, `value`, `owner_id`, `value2`) VALUES
('Allow_GET_API', 1, 0, NULL);
update conflines set value=1 where name='Allow_GET_API';
