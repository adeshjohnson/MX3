#ALTER TABLE invoices ADD number_type TINYINT default 1 COMMENT 'invoice number format type';

TRUNCATE `addresses`;
INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES (1,1,'','','','','','','','',''),(2,123,'','','','','','','','','test_reseller@email.test'),(3,1,'','','','','','','','',''),(4,1,'','','','','','','','','');

TRUNCATE `aratedetails`;
INSERT INTO `aratedetails` (`id`, `from`, `duration`, `artype`, `round`, `price`, `rate_id`, `start_time`, `end_time`, `daytype`) VALUES (1,1,-1,'minute',1,0.1,252,'00:00:00','23:59:59',''),(2,1,-1,'minute',1,0.1,253,'00:00:00','23:59:59',''),(3,1,-1,'minute',1,0.1,254,'00:00:00','23:59:59',''),(4,1,-1,'minute',1,0.1,255,'00:00:00','23:59:59',''),(5,1,-1,'minute',1,0.1,256,'00:00:00','23:59:59',''),(6,1,-1,'minute',1,0.1,257,'00:00:00','23:59:59',''),(7,1,-1,'minute',1,0.1,258,'00:00:00','23:59:59',''),(8,1,-1,'minute',1,0.1,259,'00:00:00','23:59:59',''),(9,1,-1,'minute',1,0.1,260,'00:00:00','23:59:59',''),(10,1,-1,'minute',1,0.1,261,'00:00:00','23:59:59',''),(11,1,-1,'minute',1,0.1,262,'00:00:00','23:59:59',''),(12,1,-1,'minute',1,0.1,263,'00:00:00','23:59:59',''),(13,1,-1,'minute',1,0.1,264,'00:00:00','23:59:59',''),(14,1,-1,'minute',1,0.1,265,'00:00:00','23:59:59',''),(15,1,-1,'minute',1,0.1,266,'00:00:00','23:59:59',''),(16,1,-1,'minute',1,0.1,267,'00:00:00','23:59:59',''),(17,1,-1,'minute',1,0.1,268,'00:00:00','23:59:59',''),(18,1,-1,'minute',1,0.1,269,'00:00:00','23:59:59',''),(19,1,-1,'minute',1,0.1,270,'00:00:00','23:59:59',''),(20,1,-1,'minute',1,0.1,271,'00:00:00','23:59:59',''),(21,1,-1,'minute',1,0.1,272,'00:00:00','23:59:59',''),(22,1,-1,'minute',1,0.1,273,'00:00:00','23:59:59',''),(23,1,-1,'minute',1,0.1,274,'00:00:00','23:59:59',''),(24,1,-1,'minute',1,0.1,275,'00:00:00','23:59:59',''),(25,1,-1,'minute',1,0.1,276,'00:00:00','23:59:59',''),(26,1,-1,'minute',1,0.1,277,'00:00:00','23:59:59',''),(27,1,-1,'minute',1,0.1,278,'00:00:00','23:59:59',''),(28,1,-1,'minute',1,0.1,279,'00:00:00','23:59:59',''),(29,1,-1,'minute',1,0.1,280,'00:00:00','23:59:59',''),(30,1,-1,'minute',1,0.1,281,'00:00:00','23:59:59',''),(31,1,-1,'minute',1,0.1,282,'00:00:00','23:59:59',''),(32,1,-1,'minute',1,0.1,283,'00:00:00','23:59:59',''),(33,1,-1,'minute',1,0.1,284,'00:00:00','23:59:59',''),(34,1,-1,'minute',1,0.1,285,'00:00:00','23:59:59',''),(35,1,-1,'minute',1,0.1,286,'00:00:00','23:59:59',''),(36,1,-1,'minute',1,0.1,287,'00:00:00','23:59:59',''),(37,1,-1,'minute',1,0.1,288,'00:00:00','23:59:59',''),(38,1,-1,'minute',1,0.1,289,'00:00:00','23:59:59',''),(39,1,-1,'minute',1,0.1,290,'00:00:00','23:59:59',''),(40,1,-1,'minute',1,0.1,291,'00:00:00','23:59:59',''),(41,1,-1,'minute',1,0.1,292,'00:00:00','23:59:59',''),(42,1,-1,'minute',1,0.1,293,'00:00:00','23:59:59',''),(43,1,-1,'minute',1,0.1,294,'00:00:00','23:59:59',''),(44,1,-1,'minute',1,0.1,295,'00:00:00','23:59:59',''),(45,1,-1,'minute',1,0.1,296,'00:00:00','23:59:59',''),(46,1,-1,'minute',1,0.1,297,'00:00:00','23:59:59',''),(47,1,-1,'minute',1,0.1,298,'00:00:00','23:59:59',''),(48,1,-1,'minute',1,0.1,299,'00:00:00','23:59:59',''),(49,1,-1,'minute',1,0.1,300,'00:00:00','23:59:59',''),(50,1,-1,'minute',1,0.1,301,'00:00:00','23:59:59',''),(51,1,-1,'minute',1,0.1,302,'00:00:00','23:59:59',''),(52,1,-1,'minute',1,0.1,303,'00:00:00','23:59:59',''),(53,1,-1,'minute',1,0.1,304,'00:00:00','23:59:59',''),(54,1,-1,'minute',1,0.1,305,'00:00:00','23:59:59',''),(55,1,-1,'minute',1,0.1,306,'00:00:00','23:59:59',''),(56,1,-1,'minute',1,0.1,307,'00:00:00','23:59:59',''),(57,1,-1,'minute',1,0.1,308,'00:00:00','23:59:59',''),(58,1,-1,'minute',1,0.1,309,'00:00:00','23:59:59',''),(59,1,-1,'minute',1,0.1,310,'00:00:00','23:59:59',''),(60,1,-1,'minute',1,0.1,311,'00:00:00','23:59:59',''),(61,1,-1,'minute',1,0.1,312,'00:00:00','23:59:59',''),(62,1,-1,'minute',1,0.1,313,'00:00:00','23:59:59',''),(63,1,-1,'minute',1,0.1,314,'00:00:00','23:59:59',''),(64,1,-1,'minute',1,0.1,315,'00:00:00','23:59:59',''),(65,1,-1,'minute',1,0.1,316,'00:00:00','23:59:59',''),(66,1,-1,'minute',1,0.1,317,'00:00:00','23:59:59',''),(67,1,-1,'minute',1,0.1,318,'00:00:00','23:59:59',''),(68,1,-1,'minute',1,0.1,319,'00:00:00','23:59:59',''),(69,1,-1,'minute',1,0.1,320,'00:00:00','23:59:59',''),(70,1,-1,'minute',1,0.1,321,'00:00:00','23:59:59',''),(71,1,-1,'minute',1,0.1,322,'00:00:00','23:59:59',''),(72,1,-1,'minute',1,0.1,323,'00:00:00','23:59:59',''),(73,1,-1,'minute',1,0.1,324,'00:00:00','23:59:59',''),(74,1,-1,'minute',1,0.1,325,'00:00:00','23:59:59',''),(75,1,-1,'minute',1,0.1,326,'00:00:00','23:59:59',''),(76,1,-1,'minute',1,0.1,327,'00:00:00','23:59:59',''),(77,1,-1,'minute',1,0.1,328,'00:00:00','23:59:59',''),(78,1,-1,'minute',1,0.1,329,'00:00:00','23:59:59',''),(79,1,-1,'minute',1,0.1,330,'00:00:00','23:59:59',''),(80,1,-1,'minute',1,0.1,331,'00:00:00','23:59:59',''),(81,1,-1,'minute',1,0.1,332,'00:00:00','23:59:59',''),(82,1,-1,'minute',1,0.1,333,'00:00:00','23:59:59',''),(83,1,-1,'minute',1,0.1,334,'00:00:00','23:59:59',''),(84,1,-1,'minute',1,0.1,335,'00:00:00','23:59:59',''),(85,1,-1,'minute',1,0.1,336,'00:00:00','23:59:59',''),(86,1,-1,'minute',1,0.1,337,'00:00:00','23:59:59',''),(87,1,-1,'minute',1,0.1,338,'00:00:00','23:59:59',''),(88,1,-1,'minute',1,0.1,339,'00:00:00','23:59:59',''),(89,1,-1,'minute',1,0.1,340,'00:00:00','23:59:59',''),(90,1,-1,'minute',1,0.1,341,'00:00:00','23:59:59',''),(91,1,-1,'minute',1,0.1,342,'00:00:00','23:59:59',''),(92,1,-1,'minute',1,0.1,343,'00:00:00','23:59:59',''),(93,1,-1,'minute',1,0.1,344,'00:00:00','23:59:59',''),(94,1,-1,'minute',1,0.1,345,'00:00:00','23:59:59',''),(95,1,-1,'minute',1,0.1,346,'00:00:00','23:59:59',''),(96,1,-1,'minute',1,0.1,347,'00:00:00','23:59:59',''),(97,1,-1,'minute',1,0.1,348,'00:00:00','23:59:59',''),(98,1,-1,'minute',1,0.1,349,'00:00:00','23:59:59',''),(99,1,-1,'minute',1,0.1,350,'00:00:00','23:59:59',''),(100,1,-1,'minute',1,0.1,351,'00:00:00','23:59:59',''),(101,1,-1,'minute',1,0.1,352,'00:00:00','23:59:59',''),(102,1,-1,'minute',1,0.1,353,'00:00:00','23:59:59',''),(103,1,-1,'minute',1,0.1,354,'00:00:00','23:59:59',''),(104,1,-1,'minute',1,0.1,355,'00:00:00','23:59:59',''),(105,1,-1,'minute',1,0.1,356,'00:00:00','23:59:59',''),(106,1,-1,'minute',1,0.1,357,'00:00:00','23:59:59',''),(107,1,-1,'minute',1,0.1,358,'00:00:00','23:59:59',''),(108,1,-1,'minute',1,0.1,359,'00:00:00','23:59:59',''),(109,1,-1,'minute',1,0.1,360,'00:00:00','23:59:59',''),(110,1,-1,'minute',1,0.1,361,'00:00:00','23:59:59',''),(111,1,-1,'minute',1,0.1,362,'00:00:00','23:59:59',''),(112,1,-1,'minute',1,0.1,363,'00:00:00','23:59:59',''),(113,1,-1,'minute',1,0.1,364,'00:00:00','23:59:59',''),(114,1,-1,'minute',1,0.1,365,'00:00:00','23:59:59',''),(115,1,-1,'minute',1,0.1,366,'00:00:00','23:59:59',''),(116,1,-1,'minute',1,0.1,367,'00:00:00','23:59:59',''),(117,1,-1,'minute',1,0.1,368,'00:00:00','23:59:59',''),(118,1,-1,'minute',1,0.1,369,'00:00:00','23:59:59',''),(119,1,-1,'minute',1,0.1,370,'00:00:00','23:59:59',''),(120,1,-1,'minute',1,0.1,371,'00:00:00','23:59:59',''),(121,1,-1,'minute',1,0.1,372,'00:00:00','23:59:59',''),(122,1,-1,'minute',1,0.1,373,'00:00:00','23:59:59',''),(123,1,-1,'minute',1,0.1,374,'00:00:00','23:59:59',''),(124,1,-1,'minute',1,0.1,375,'00:00:00','23:59:59',''),(125,1,-1,'minute',1,0.1,376,'00:00:00','23:59:59',''),(126,1,-1,'minute',1,0.1,377,'00:00:00','23:59:59',''),(127,1,-1,'minute',1,0.1,378,'00:00:00','23:59:59',''),(128,1,-1,'minute',1,0.1,379,'00:00:00','23:59:59',''),(129,1,-1,'minute',1,0.1,380,'00:00:00','23:59:59',''),(130,1,-1,'minute',1,0.1,381,'00:00:00','23:59:59',''),(131,1,-1,'minute',1,0.1,382,'00:00:00','23:59:59',''),(132,1,-1,'minute',1,0.1,383,'00:00:00','23:59:59',''),(133,1,-1,'minute',1,0.1,384,'00:00:00','23:59:59',''),(134,1,-1,'minute',1,0.1,385,'00:00:00','23:59:59',''),(135,1,-1,'minute',1,0.1,386,'00:00:00','23:59:59',''),(136,1,-1,'minute',1,0.1,387,'00:00:00','23:59:59',''),(137,1,-1,'minute',1,0.1,388,'00:00:00','23:59:59',''),(138,1,-1,'minute',1,0.1,389,'00:00:00','23:59:59',''),(139,1,-1,'minute',1,0.1,390,'00:00:00','23:59:59',''),(140,1,-1,'minute',1,0.1,391,'00:00:00','23:59:59',''),(141,1,-1,'minute',1,0.1,392,'00:00:00','23:59:59',''),(142,1,-1,'minute',1,0.1,393,'00:00:00','23:59:59',''),(143,1,-1,'minute',1,0.1,394,'00:00:00','23:59:59',''),(144,1,-1,'minute',1,0.1,395,'00:00:00','23:59:59',''),(145,1,-1,'minute',1,0.1,396,'00:00:00','23:59:59',''),(146,1,-1,'minute',1,0.1,397,'00:00:00','23:59:59',''),(147,1,-1,'minute',1,0.1,398,'00:00:00','23:59:59',''),(148,1,-1,'minute',1,0.1,399,'00:00:00','23:59:59',''),(149,1,-1,'minute',1,0.1,400,'00:00:00','23:59:59',''),(150,1,-1,'minute',1,0.1,401,'00:00:00','23:59:59',''),(151,1,-1,'minute',1,0.1,402,'00:00:00','23:59:59',''),(152,1,-1,'minute',1,0.1,403,'00:00:00','23:59:59',''),(153,1,-1,'minute',1,0.1,404,'00:00:00','23:59:59',''),(154,1,-1,'minute',1,0.1,405,'00:00:00','23:59:59',''),(155,1,-1,'minute',1,0.1,406,'00:00:00','23:59:59',''),(156,1,-1,'minute',1,0.1,407,'00:00:00','23:59:59',''),(157,1,-1,'minute',1,0.1,408,'00:00:00','23:59:59',''),(158,1,-1,'minute',1,0.1,409,'00:00:00','23:59:59',''),(159,1,-1,'minute',1,0.1,410,'00:00:00','23:59:59',''),(160,1,-1,'minute',1,0.1,411,'00:00:00','23:59:59',''),(161,1,-1,'minute',1,0.1,412,'00:00:00','23:59:59',''),(162,1,-1,'minute',1,0.1,413,'00:00:00','23:59:59',''),(163,1,-1,'minute',1,0.1,414,'00:00:00','23:59:59',''),(164,1,-1,'minute',1,0.1,415,'00:00:00','23:59:59',''),(165,1,-1,'minute',1,0.1,416,'00:00:00','23:59:59',''),(166,1,-1,'minute',1,0.1,417,'00:00:00','23:59:59',''),(167,1,-1,'minute',1,0.1,418,'00:00:00','23:59:59',''),(168,1,-1,'minute',1,0.1,419,'00:00:00','23:59:59',''),(169,1,-1,'minute',1,0.1,420,'00:00:00','23:59:59',''),(170,1,-1,'minute',1,0.1,421,'00:00:00','23:59:59',''),(171,1,-1,'minute',1,0.1,422,'00:00:00','23:59:59',''),(172,1,-1,'minute',1,0.1,423,'00:00:00','23:59:59',''),(173,1,-1,'minute',1,0.1,424,'00:00:00','23:59:59',''),(174,1,-1,'minute',1,0.1,425,'00:00:00','23:59:59',''),(175,1,-1,'minute',1,0.1,426,'00:00:00','23:59:59',''),(176,1,-1,'minute',1,0.1,427,'00:00:00','23:59:59',''),(177,1,-1,'minute',1,0.1,428,'00:00:00','23:59:59',''),(178,1,-1,'minute',1,0.1,429,'00:00:00','23:59:59',''),(179,1,-1,'minute',1,0.1,430,'00:00:00','23:59:59',''),(180,1,-1,'minute',1,0.1,431,'00:00:00','23:59:59',''),(181,1,-1,'minute',1,0.1,432,'00:00:00','23:59:59',''),(182,1,-1,'minute',1,0.1,433,'00:00:00','23:59:59',''),(183,1,-1,'minute',1,0.1,434,'00:00:00','23:59:59',''),(184,1,-1,'minute',1,0.1,435,'00:00:00','23:59:59',''),(185,1,-1,'minute',1,0.1,436,'00:00:00','23:59:59',''),(186,1,-1,'minute',1,0.1,437,'00:00:00','23:59:59',''),(187,1,-1,'minute',1,0.1,438,'00:00:00','23:59:59',''),(188,1,-1,'minute',1,0.1,439,'00:00:00','23:59:59',''),(189,1,-1,'minute',1,0.1,440,'00:00:00','23:59:59',''),(190,1,-1,'minute',1,0.1,441,'00:00:00','23:59:59',''),(191,1,-1,'minute',1,0.1,442,'00:00:00','23:59:59',''),(192,1,-1,'minute',1,0.1,443,'00:00:00','23:59:59',''),(193,1,-1,'minute',1,0.1,444,'00:00:00','23:59:59',''),(194,1,-1,'minute',1,0.1,445,'00:00:00','23:59:59',''),(195,1,-1,'minute',1,0.1,446,'00:00:00','23:59:59',''),(196,1,-1,'minute',1,0.1,447,'00:00:00','23:59:59',''),(197,1,-1,'minute',1,0.1,448,'00:00:00','23:59:59',''),(198,1,-1,'minute',1,0.1,449,'00:00:00','23:59:59',''),(199,1,-1,'minute',1,0.1,450,'00:00:00','23:59:59',''),(200,1,-1,'minute',1,0.1,451,'00:00:00','23:59:59',''),(201,1,-1,'minute',1,0.1,452,'00:00:00','23:59:59',''),(202,1,-1,'minute',1,0.1,453,'00:00:00','23:59:59',''),(203,1,-1,'minute',1,0.1,454,'00:00:00','23:59:59',''),(204,1,-1,'minute',1,0.1,455,'00:00:00','23:59:59',''),(205,1,-1,'minute',1,0.1,456,'00:00:00','23:59:59',''),(206,1,-1,'minute',1,0.1,457,'00:00:00','23:59:59',''),(207,1,-1,'minute',1,0.1,458,'00:00:00','23:59:59',''),(208,1,-1,'minute',1,0.1,459,'00:00:00','23:59:59',''),(209,1,-1,'minute',1,0.1,460,'00:00:00','23:59:59',''),(210,1,-1,'minute',1,0.1,461,'00:00:00','23:59:59',''),(211,1,-1,'minute',1,0.1,462,'00:00:00','23:59:59',''),(212,1,-1,'minute',1,0.1,463,'00:00:00','23:59:59',''),(213,1,-1,'minute',1,0.1,464,'00:00:00','23:59:59',''),(214,1,-1,'minute',1,0.1,465,'00:00:00','23:59:59',''),(215,1,-1,'minute',1,0.1,466,'00:00:00','23:59:59',''),(216,1,-1,'minute',1,0.1,467,'00:00:00','23:59:59',''),(217,1,-1,'minute',1,0.1,468,'00:00:00','23:59:59',''),(218,1,-1,'minute',1,0.1,469,'00:00:00','23:59:59',''),(219,1,-1,'minute',1,0.1,470,'00:00:00','23:59:59',''),(220,1,-1,'minute',1,0.1,471,'00:00:00','23:59:59',''),(221,1,-1,'minute',1,0.1,472,'00:00:00','23:59:59',''),(222,1,-1,'minute',1,0.1,473,'00:00:00','23:59:59',''),(223,1,-1,'minute',1,0.1,474,'00:00:00','23:59:59',''),(224,1,-1,'minute',1,0.1,475,'00:00:00','23:59:59',''),(225,1,-1,'minute',1,0.1,476,'00:00:00','23:59:59',''),(226,1,-1,'minute',1,0.1,477,'00:00:00','23:59:59',''),(227,1,-1,'minute',1,0.1,478,'00:00:00','23:59:59',''),(228,1,-1,'minute',1,0.1,479,'00:00:00','23:59:59',''),(229,1,-1,'minute',1,0.1,480,'00:00:00','23:59:59',''),(230,1,-1,'minute',1,0.1,481,'00:00:00','23:59:59',''),(231,1,-1,'minute',1,0.1,482,'00:00:00','23:59:59',''),(232,1,-1,'minute',1,0.1,483,'00:00:00','23:59:59',''),(233,1,-1,'minute',1,0.1,484,'00:00:00','23:59:59',''),(234,1,-1,'minute',1,0.1,485,'00:00:00','23:59:59',''),(235,1,-1,'minute',1,0.1,486,'00:00:00','23:59:59',''),(236,1,-1,'minute',1,0.1,487,'00:00:00','23:59:59','');

TRUNCATE `calls`;
INSERT INTO `calls` (`id`, `calldate`, `clid`, `src`, `dst`, `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`, `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `peerip`, `recvip`, `sipfrom`, `uri`, `useragent`, `peername`, `t38passthrough`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`) VALUES 
# outgoing 2009-01-01
(9 ,'2009-01-01 00:00:01','','101','123123','','','','','',10,20,'ANSWERED',0,'2','1232113370.3','',5,0,0,0,0,1,0,0,1,0,0,1,2,0,0,0,0,0,0,0,0,'1231',1,16,'Local','','','','','','',0,0,0,'123123',0,0,'','',0,0,0),
(10,'2009-01-01 00:00:02','','101','123123','','','','','',20,30,'ANSWERED',0,'2','1232113371.3','',6,0,0,0,0,1,0,0,1,2,0,1,3,0,0,0,0,0,0,0,0,'1231',1,16,'Local','','','','','','',0,0,0,'123123',0,0,'','',0,0,0),
(11,'2009-01-01 00:00:03','','101','123123','','','','','',30,40,'ANSWERED',0,'2','1232113372.3','',7,0,0,0,0,1,0,0,1,3,0,1,4,0,0,0,0,0,0,0,0,'1231',1,16,'Local','','','','','','',0,0,0,'123123',0,0,'','',0,0,0),
(12,'2009-01-01 00:00:04','','101','123123','','','','','',40,50,'ANSWERED',0,'2','1232113373.3','',2,0,0,0,0,1,0,0,1,5,0,1,5,3,0,0,4,0,0,0,0,'1231',1,16,'Local','','','','','','',0,0,0,'123123',0,0,'','',0,0,0),
# incoming 2009-01-02
# call to admins device
(13,'2009-01-02 00:00:01','37046246362','37046246362','37063042438','','','','','',10,20,'ANSWERED',0,'2','1232113374.3','',1,5,0,1,0,1,0,0,1,-1,0,1,2,0,0,0,0,0,0,0,0,'3706',1,16,'Outside','','','','','','',0,1,1,'37063042438',0,1,'','',0,0,20),
# call to users device
(14,'2009-01-02 00:00:02','37046246362','37046246362','37063042438','','','','','',20,30,'ANSWERED',0,'2','1232113375.3','',1,4,0,1,0,1,0,0,1,-1,0,1,3,0,0,0,0,0,0,0,0,'3706',1,16,'Outside','','','','','','',0,2,2,'37063042438',0,1,'','',0,0,30),
# call to resellers device
(15,'2009-01-02 00:00:03','37046246362','37046246362','37063042438','','','','','',30,40,'ANSWERED',0,'2','1232113376.3','',1,6,0,1,0,1,0,0,1,-1,0,1,4,0,0,0,0,0,0,0,0,'3706',1,16,'Outside','','','','','','',0,3,3,'37063042438',0,1,'','',0,0,40),
# call to resellers users device
(16,'2009-01-02 00:00:04','37046246362','37046246362','37063042438','','','','','',40,50,'ANSWERED',0,'2','1232113377.3','',1,7,0,1,0,1,0,0,1,-1,0,1,5,3,0,0,4,0,0,0,0,'3706',1,16,'Outside','','','','','','',0,4,4,'37063042438',0,1,'','',0,99,50),
# incoming 2008-01-01 by did_inc_price
# call to admins device
(17,'2008-01-01 00:00:01','37046246362','37046246362','37063042438','','','','','',10,20,'ANSWERED',0,'2','1232113374.3','',5,0,0,0,0,1,0,0,1,-1,0,1,2,0,0,0,0,0,0,0,0,'3706',0,16,'Outside','','','','','','',0,1,1,'37063042438',0,0,'','',0,0,20),
# call to users device
(18,'2008-01-01 00:00:02','37046246362','37046246362','37063042438','','','','','',20,30,'ANSWERED',0,'2','1232113375.3','',4,0,0,0,0,1,0,0,1,-1,0,1,3,0,0,0,0,0,0,0,0,'3706',0,16,'Outside','','','','','','',0,2,2,'37063042438',0,0,'','',0,0,30),
# call to resellers device
(19,'2008-01-01 00:00:03','37046246362','37046246362','37063042438','','','','','',30,40,'ANSWERED',0,'2','1232113376.3','',6,0,0,0,0,1,0,0,1,-1,0,1,4,0,0,0,0,0,0,0,0,'3706',0,16,'Outside','','','','','','',0,3,3,'37063042438',0,0,'','',0,0,40),
# call to resellers users device
(20,'2008-01-01 00:00:04','37046246362','37046246362','37063042438','','','','','',40,50,'ANSWERED',0,'2','1232113377.3','',7,0,0,0,0,1,0,0,1,-1,0,1,5,3,0,0,4,0,0,0,0,'3706',0,16,'Outside','','','','','','',0,4,4,'37063042438',0,0,'','',0,0,50);


TRUNCATE `cardgroups`;
INSERT INTO `cardgroups` (`id`, `name`, `description`, `price`, `setup_fee`, `ghost_min_perc`, `daily_charge`, `tariff_id`, `lcr_id`, `created_at`, `valid_from`, `valid_till`, `vat_percent`, `number_length`, `pin_length`, `dialplan_id`, `image`, `location_id`, `owner_id`, `tax_id`) VALUES (1,'Test_cardgroup','Test_cardgroup description',10.0840336134454,1,100,0.1,2,1,'2009-04-16 04:57:41','2009-04-16 00:00:00','2012-04-16 23:59:59',19,10,4,0,'example.jpg',1,0,6);

TRUNCATE `cards`;
INSERT INTO `cards` (`id`, `balance`, `cardgroup_id`, `sold`, `number`, `pin`, `first_use`, `daily_charge_paid_till`, `frozen_balance`, `owner_id`, `callerid`) VALUES (1,10.0840336134454,1,0,'1111111000','7856',NULL,NULL,0,0,NULL),(2,10.0840336134454,1,0,'1111111001','9812',NULL,NULL,0,0,NULL),(3,10.0840336134454,1,0,'1111111002','8722',NULL,NULL,0,0,NULL),(4,10.0840336134454,1,0,'1111111003','1360',NULL,NULL,0,0,NULL),(5,10.0840336134454,1,0,'1111111004','9323',NULL,NULL,0,0,NULL),(6,10.0840336134454,1,0,'1111111005','5774',NULL,NULL,0,0,NULL),(7,10.0840336134454,1,0,'1111111006','8870',NULL,NULL,0,0,NULL),(8,10.0840336134454,1,0,'1111111007','6930',NULL,NULL,0,0,NULL),(9,10.0840336134454,1,0,'1111111008','3034',NULL,NULL,0,0,NULL),(10,10.0840336134454,1,0,'1111111009','0521',NULL,NULL,0,0,NULL),(11,10.0840336134454,1,0,'1111111010','1452',NULL,NULL,0,0,NULL),(12,10.0840336134454,1,0,'1111111011','3996',NULL,NULL,0,0,NULL),(13,10.0840336134454,1,0,'1111111012','7901',NULL,NULL,0,0,NULL),(14,10.0840336134454,1,0,'1111111013','7635',NULL,NULL,0,0,NULL),(15,10.0840336134454,1,0,'1111111014','1552',NULL,NULL,0,0,NULL),(16,10.0840336134454,1,0,'1111111015','4677',NULL,NULL,0,0,NULL),(17,10.0840336134454,1,0,'1111111016','2392',NULL,NULL,0,0,NULL),(18,10.0840336134454,1,0,'1111111017','2765',NULL,NULL,0,0,NULL),(19,10.0840336134454,1,0,'1111111018','5602',NULL,NULL,0,0,NULL),(20,10.0840336134454,1,0,'1111111019','7484',NULL,NULL,0,0,NULL),(21,10.0840336134454,1,0,'1111111020','8629',NULL,NULL,0,0,NULL);

TRUNCATE `devicegroups`;
INSERT INTO `devicegroups` (`id`, `user_id`, `address_id`, `name`, `added`, `primary`) VALUES (1,3,2,'primary','2009-03-31 11:38:55',1),(2,4,3,'primary','2009-03-31 11:39:32',1),(3,5,4,'primary','2009-03-31 11:53:07',1);

TRUNCATE `devices`;
INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`) VALUES 
# provider
(1,'prov1','22.33.44.55','test','mor','22.33.44.55',4569,0,1,'','prov_test',0,'test','IAX2',-1,0,1,0,0,'no','all','alaw;ulaw;g729;gsm','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','no','no','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
# devices for test user with id = 2
(2,'101','dynamic','101','mor_local','0.0.0.0',0,1175892667,2,'\"101\" <101>','101',0,'101','IAX2',2,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device #1',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
(3,'102','dynamic','102','mor_local','0.0.0.0',0,1175892667,3,'\"102\" <102>','102',0,'102','FAX',2,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test FAX device',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
(4,'1002','dynamic','vejs9cut','mor_local','',0,0,4,NULL,'1002',0,'1002','IAX2',2,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','1000',NULL,'no',NULL,'rfc2833',0,0,'','','no','no','','no','no',1,'',0,0,'211194',0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
# device for admin
(5,'103','dynamic','103','mor_local','0.0.0.0',0,1175892667,2,'\"103\" <103>','103',0,'103','IAX2',0,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for Admin',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
# device for reseller
(6,'104','dynamic','104','mor_local','0.0.0.0',0,1175892667,2,'\"104\" <104>','104',0,'104','IAX2',3,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for Reseller',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
# device for resellers user
(7,'105','dynamic','105','mor_local','0.0.0.0',0,1175892667,2,'\"105\" <105>','105',0,'105','IAX2',5,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','yes','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for Resellers User',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL);

TRUNCATE `dids`;
INSERT INTO `dids` (id, did, status, user_id, device_id, subscription_id, reseller_id, closed_till, dialplan_id, language, provider_id, comment, call_limit) VALUES ('1', '37063042438', 'free', '0', '0', '0', '0', '2006-01-01 00:00:00', '0', 'en', '1', null, '0');

TRUNCATE `extlines`;
INSERT INTO `extlines` (`id`, `context`, `exten`, `priority`, `app`, `appdata`, `device_id`) VALUES (1,'mor','556',1,'ChanSpy','IAX2|q',0),(15,'mor_local','101',1,'GotoIf','$[${LEN(${CALLED_TO})} > 0]?2:4',1),(16,'mor_local','101',2,'Set','CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}',1),(17,'mor_local','101',3,'Goto','101|5',1),(18,'mor_local','101',4,'Set','CALLED_TO=${EXTEN}',1),(19,'mor_local','101',5,'NoOp','MOR starts',1),(20,'mor_local','101',6,'GotoIf','$[${LEN(${CALLERID(NAME)})} > 0]?9:7',1),(21,'mor_local','101',7,'GotoIf','$[${LEN(${mor_cid_name})} > 0]?8:9',1),(22,'mor_local','101',8,'Set','CALLERID(NAME)=${mor_cid_name}',1),(23,'mor_local','101',9,'Dial','IAX2/101',1),(24,'mor_local','101',10,'GotoIf','$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"]?301',1),(25,'mor_local','101',11,'Hangup','',1),(26,'mor_local','101',209,'Background','busy',1),(27,'mor_local','101',210,'Busy','10',1),(28,'mor_local','101',211,'Hangup','',1),(29,'mor_local','101',301,'Ringing','',1),(30,'mor_local','101',302,'Wait','120',1),(31,'mor_local','101',303,'Hangup','',1),(36,'mor','BUSY',1,'Busy','10',0),(37,'mor','BUSY',2,'Hangup','',0),(40,'mor','FAILED',1,'Congestion','4',0),(41,'mor','FAILED',2,'Hangup','',0),(42,'mor_local','*89',1,'VoiceMailMain','',0),(43,'mor_local','*89',2,'Hangup','',0),(44,'mor','fax',1,'Goto','mor_fax2email|123|1',0),(45,'mor_local','102',1,'GotoIf','$[${LEN(${CALLED_TO})} > 0]?2:4',2),(46,'mor_local','102',2,'NoOp','CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}',2),(47,'mor_local','102',3,'Goto','102|5',2),(48,'mor_local','102',4,'Set','CALLED_TO=${EXTEN}',2),(49,'mor_local','102',5,'Set','MOR_FAX_ID=2',2),(50,'mor_local','102',6,'Set','FAXSENDER=${CALLERID(number)}',2),(51,'mor_local','102',7,'Goto','mor_fax2email|${EXTEN}|1',2),(52,'mor_local','102',401,'NoOp','NO ANSWER',2),(53,'mor_local','102',402,'Hangup','',2),(54,'mor_local','102',201,'NoOp','BUSY',2),(55,'mor_local','102',202,'GotoIf','${LEN(${MOR_CALL_FROM_DID}) = 1}?203:BUSY|1',2),(56,'mor_local','102',203,'Busy','1',2),(57,'mor_local','102',301,'NoOp','FAILED',2),(58,'mor_local','102',302,'GotoIf','${LEN(${MOR_CALL_FROM_DID}) = 1}?303:FAILED|1',2),(59,'mor_local','102',303,'Congestion','1',2),(60,'mor_local','*97',1,'AGI','mor_acc2user',0),(61,'mor_local','*97',2,'VoiceMailMain','s${MOR_EXT}',0),(62,'mor_local','*97',3,'Hangup','',0),(63,'mor','fax',1,'Goto','mor_fax2email|123|1',0),(64,'mor_local','_X.',1,'Goto','mor|${EXTEN}|1',0),(65,'mor_local','_*X.',1,'Goto','mor|${EXTEN}|1',0),(74,'mor_voicemail','_X.',1,'VoiceMail','${EXTEN}|${MOR_VM}',0),(75,'mor_voicemail','_X.',2,'Hangup','',0),(76,'mor','HANGUP',1,'Hangup','',0),(77,'mor','HANGUP_NOW',1,'Hangup','',0),(78,'mor','_X.',1,'NoOp','MOR starts',0),(79,'mor','_X.',2,'Set','TIMEOUT(response)=20',0),(80,'mor','_X.',3,'Set','TIMEOUT(digit)=10',0),(81,'mor','_X.',4,'mor','${EXTEN}',0),(82,'mor','_X.',5,'GotoIf','$[\"${MOR_CARD_USED}\" != \"\"]?mor_callingcard|s|1',0),(83,'mor','_X.',6,'GotoIf','$[\"${MOR_TRUNK}\" = \"1\"]?HANGUP_NOW|1',0),(84,'mor','_X.',7,'GotoIf','$[$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"] | $[\"${DIALSTATUS}\" = \"CONGESTION\"]]?FAILED|1',0),(85,'mor','_X.',8,'GotoIf','$[\"${DIALSTATUS}\" = \"BUSY\"]?BUSY|1:HANGUP|1',0),(86,'mor_local','1002',1,'NoOp','${MOR_MAKE_BUSY}',4),(87,'mor_local','1002',2,'GotoIf','$[\"${MOR_MAKE_BUSY}\" = \"1\"]?201',4),(88,'mor_local','1002',3,'GotoIf','$[${LEN(${CALLED_TO})} > 0]?4:6',4),(89,'mor_local','1002',4,'NoOp','CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}',4),(90,'mor_local','1002',5,'Goto','1002|7',4),(91,'mor_local','1002',6,'Set','CALLED_TO=${EXTEN}',4),(92,'mor_local','1002',7,'NoOp','MOR starts',4),(93,'mor_local','1002',8,'GotoIf','$[${LEN(${CALLERID(NAME)})} > 0]?11:9',4),(94,'mor_local','1002',9,'GotoIf','$[${LEN(${mor_cid_name})} > 0]?10:11',4),(95,'mor_local','1002',10,'Set','CALLERID(NAME)=${mor_cid_name}',4),(96,'mor_local','1002',11,'Dial','IAX2/1002|60',4),(97,'mor_local','1002',12,'GotoIf','$[$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"]|$[\"${DIALSTATUS}\" = \"CONGESTION\"]]?301',4),(98,'mor_local','1002',13,'GotoIf','$[\"${DIALSTATUS}\" = \"BUSY\"]?201',4),(99,'mor_local','1002',14,'GotoIf','$[\"${DIALSTATUS}\" = \"NOANSWER\"]?401',4),(100,'mor_local','1002',15,'Hangup','',4),(101,'mor_local','1002',401,'NoOp','NO ANSWER',4),(102,'mor_local','1002',402,'Hangup','',4),(103,'mor_local','1002',201,'NoOp','BUSY',4),(104,'mor_local','1002',202,'GotoIf','${LEN(${MOR_CALL_FROM_DID}) = 1}?203:mor|BUSY|1',4),(105,'mor_local','1002',203,'Busy','10',4),(106,'mor_local','1002',301,'NoOp','FAILED',4),(107,'mor_local','1002',302,'GotoIf','${LEN(${MOR_CALL_FROM_DID}) = 1}?303:mor|FAILED|1',4),(108,'mor_local','1002',303,'Congestion','4',4);

TRUNCATE `services`;
INSERT INTO `services` (`id`, `name`, `servicetype`, `destinationgroup_id`, `periodtype`, `price`, `owner_id`, `quantity`) VALUES (1,'Test_periodic_service','periodic_fee',NULL,'month',10,0,1);

;TRUNCATE `tariffs`;
;INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES (1,'Test Tariff','provider',0,'USD'),(2,'Test Tariff for Users','user_wholesale',0,'USD'),(3,'tariff','user',3,'USD'),(4,'Test Tariff + 0.1','user',0,'USD');

TRUNCATE `users`;
INSERT INTO `users` (`id`, `username`, `password`, `usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `c2c_service_active`, `temporary_id`, `send_invoice_types`, `call_limit`, `c2c_call_price`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`) VALUES 
(0,'admin','6c7ca345f63f835cb353ff15bd6c5e052ec08e7a','admin',1,'System','Admin',3,0,0,0,1,1,0,2,0,'2000-01-01 00:00:00',0,0,1,0,-1,'','','2007-03-26','',1,'',18,1,'',0,0,0,'2000-01-01 00:00:00','hfttv7bcqt',0,NULL,1,0,NULL,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,0,1,0),
(2,'101','dd2dfa50dc8feca1e5303a87b2c6a42db3ebe102','user',0,'Test User','#1',3,1,0,0,1,1,0,2,0,'2000-01-01 00:00:00',0,0,1,0,-1,NULL,NULL,NULL,NULL,NULL,NULL,18,NULL,NULL,0,0,0,'2000-01-01 00:00:00',NULL,0,NULL,1,0,NULL,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,0,1,0),
(3,'reseller','91dec0f4d00fadb39bf733c5418e9af2151624c6','reseller',0,'Test','Reseller',3,0,0,0,1,1,0,4,0,NULL,0,0,1,0,-1,'','0000000001','2009-03-31','',123,'',19,2,'',0,0,0,'2000-01-01 00:00:00','qg2audn8qa',0,NULL,0,0,NULL,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,1,1,0),
(4,'accountant','ed05464507ccc00676ed0b32267ad4ece385c119','accountant',0,'Test','Accountant',3,0,0,0,1,1,0,2,0,NULL,0,0,1,0,-1,'','0000000002','2009-03-31','',123,'',0,3,'',0,0,0,'2000-01-01 00:00:00',NULL,0,NULL,1,0,NULL,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,2,1,0),
(5,'user_reseller','6a9f8db8df3143d212fe44572d51576c66b0dca7','user',0,'User','Resellers',3,0,0,0,1,1,0,3,0,NULL,0,0,1,0,-1,'','0000000003','2009-03-31','',1,'',19,4,'',3,0,0,'2000-01-01 00:00:00',NULL,0,NULL,0,0,NULL,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,3,1,0);
UPDATE users SET id = 0 WHERE username = 'admin';

TRUNCATE `subscriptions`;
INSERT INTO `subscriptions` (`id`, `service_id`, `user_id`, `device_id`, `activation_start`, `activation_end`, `added`, `memo`) VALUES (1,1,2,NULL,'2009-03-22 09:25:00','2013-07-22 09:25:00','2009-04-22 09:25:00','Test_preriodic_service_memo');

TRUNCATE `recordings`;
INSERT INTO `recordings` (`id`, `datetime`, `src`, `dst`, `src_device_id`, `dst_device_id`, `call_id`, `user_id`, `path`, `deleted`, `send_time`, `comment`, `size`, `uniqueid`, `visible_to_user`, `dst_user_id`, `local`, `visible_to_dst_user`) VALUES
(1, '2009-01-01 00:00:04', '101', '123123', 2, 0, 12, 2, '', 0, NULL, '', 1024, '1232113373.3', 1, 0, 1, 1),
(2, '2009-01-01 00:00:04', '101', '123123', 2, 0, 12, 2, '', 0, NULL, '', 928797, '1232113373.3', 0, 0, 1, 1),
(3, '2009-01-02 00:00:02', '37046246362', '37063042438', 0, 4, 14, 0, '', 0, NULL, '', 76346, '1232113375.3', 1, 2, 1, 1),
(4, '2009-01-02 00:00:02', '37046246362', '37063042438', 0, 4, 14, 0, '', 0, NULL, '', 578965, '1232113375.3', 1, 2, 1, 0),
(5, '2009-01-02 00:00:04', '37046246362', '37063042438', 2, 4, 16, 2, '', 0, NULL, '', 98765, '1232113377.3', 1, 2, 1, 1),
(6, '2009-01-02 00:00:04', '37046246362', '37063042438', 2, 4, 16, 2, '', 0, NULL, '', 435464, '1232113377.3', 0, 2, 1, 0);

TRUNCATE `flatrate_data`;

INSERT INTO `flatrate_data` (`year_month`, `minutes`, `subscription_id`) VALUES
(DATE_FORMAT(CURDATE(), "%Y-%m"), 50, 2);

TRUNCATE `activecalls`;
INSERT INTO `activecalls`
  (`id`, `server_id`, `uniqueid`,         `start_time`, `answer_time`, `transfer_time`, `src`,         `dst`,       `src_device_id`, `dst_device_id`, `channel`,                   `dstchannel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`) VALUES
  (1,    2,           '1249296551.111095',NOW(),        NULL,          NULL,            '306984327343','63727007889',5,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     1,              0,       0,         0,          '63727007889'),
  (2,    1,           '1249298495.111725',NOW()+1,      NULL,          NULL,            '306984327344','63727007885',5,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              0,       0,         0,          '63727007885'),
  (3,    1,           '1249298495.111726',NOW()+2,      NULL,          NULL,            '306984327345','63727007886',2,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              0,       2,         0,          '63727007886'),
  (4,    1,           '1249298495.111727',NOW()+3,      NULL,          NULL,            '306984327347','63727007887',7,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              0,       5,         3,          '63727007887');

TRUNCATE `sms_messages`;
INSERT INTO `sms_messages`
(`id`, `sending_date`,       `status_code`, `provider_id`, `provider_rate`, `provider_price`, `user_id`, `user_rate`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_price`, `prefix`, `number`,      `clickatell_message_id`) VALUES
(1,    '2009-12-01 10:54:23','1',            NULL,          0,              0,                0,         0,           10,           0,             0,               0,                NULL,     '+37061111111','1234');


# Email configuration
UPDATE conflines SET value = "vilnius.balt.net" WHERE NAME = "Email_Smtp_Server";
UPDATE conflines SET value = "" WHERE NAME = "Email_Login";
UPDATE conflines SET value = "" WHERE NAME = "Email_Password";

TRUNCATE `actions`;
INSERT INTO `actions`
(`id`, `user_id`, `date`,               `action`,   `data`, `data2`, `processed`, `target_type`, `target_id`, `data3`, `data4`) VALUES
(1,    0,         '2010-01-01 00:00:01','test_time','',     '',      0,           'user',        0,           NULL,    NULL),
(2,    0,         '2010-01-01 23:59:58','test_time','',     '',      0,           'user',        0,           NULL,    NULL);

update servers set active=0;
