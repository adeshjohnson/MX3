#############################################################################################################
#																											                                                      #
#																											                                                      #
#						THIS FILE IS COMPILATION OF UPDATE COMMANDS FOR MOR DATABASE						                        #
#		 	 	BEFORE APPLYING ANY OF FOLLOWING UPDATE COMMANDS CHECK YOUR DATABASE FIRST					                #
#	  		 THIS FILE IS FOR TESTERS ONLY - MAKE BACKUP BEFORE PLAYING WITH YOUR DATABASE!!!				            #
#																											                                                      #
#																											                                                      #
#############################################################################################################

ALTER TABLE cards ADD user_id INT default -1 COMMENT 'User ID';

ALTER TABLE users ADD time_zone INT default 0 COMMENT 'Time zone number';

ALTER TABLE services ADD selfcost_price double NOT NULL DEFAULT '0';

ALTER TABLE users ADD spy_device_id INT default 0 COMMENT 'ChanSpy device ID';

ALTER TABLE cards ADD UNIQUE (number);

ALTER TABLE cron_settings ADD provider_target_id INT(11) NOT NULL ;

ALTER TABLE cron_settings ADD provider_to_target_id INT(11) NOT NULL ;

CREATE TABLE `common_use_providers` (`id` INT NOT NULL AUTO_INCREMENT , `provider_id` INT NOT NULL , `reseller_id` INT NOT NULL , `tariff_id` INT NOT NULL , PRIMARY KEY ( `id` )) ENGINE = InnoDB;

ALTER TABLE lcrs ADD first_provider_percent_limit FLOAT DEFAULT 0 NOT NULL ;

ALTER TABLE dids ADD reseller_comment varchar(255) default NULL;

ALTER TABLE devices ADD calleridpres ENUM ('allowed_not_screened', 'allowed_passed_screen', 'allowed_failed_screen', 'allowed', 'prohib_not_screened', 'prohib_passed_screen', 'prohib_failed_screen', 'prohib', 'unavailable') DEFAULT NULL;

ALTER TABLE cardgroups ADD disable_voucher TINYINT(1) default 0;

ALTER TABLE devices ADD use_ani_for_cli TINYINT(1) default 0;

INSERT INTO `pbxfunctions` (id, name, context, extension, priority, pf_type, user_id, allow_resellers) VALUES (9, 'ringgroupID', 'ringgroupID', 's', '1', 'ringgroupID', 0, 0);

CREATE TABLE `ringgroups` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `comment` BLOB,
  `timeout` INTEGER,
  `options` varchar(255),
  `strategy` ENUM ('ringall', 'hunt', 'memoryhunt', 'ringall-prim', 'hunt-prim', 'memoryhunt-prim', 'firstavailable', 'firstnotonphone') DEFAULT 'ringall' NOT NULL,
  `cid_prefix` varchar(255),
  `did_id` int(11),
  `user_id` int(11) DEFAULT 0 NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `ringgroups_devices` (
  `id` int(11) NOT NULL auto_increment,
  `ringgroup_id` int(11) NOT NULL,
  `device_id` int(11) NOT NULL,
  `priority` INTEGER,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE dialplans ADD COLUMN  `data9` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data10` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data11` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data12` varchar(255) default NULL;

ALTER TABLE cardgroups ADD solo_pinless TINYINT(1) default 0;
ALTER TABLE locationrules ADD did_id int(11) COMMENT 'Route to DID';
ALTER TABLE cards ADD name VARCHAR(255) default '' COMMENT 'Card name';

ALTER TABLE cs_invoices ADD tax_id int(11) default NULL COMMENT 'Tax for invoice';
ALTER TABLE cs_invoices ADD balance_with_tax float default 0 COMMENT 'Balance with tax for invoice';

ALTER TABLE devices ADD language VARCHAR(10) default 'en' COMMENT 'Language of device';
ALTER TABLE cards ADD language VARCHAR(10) default 'en' COMMENT 'Language of card';

ALTER TABLE payments ADD description BLOB COMMENT 'payment description';

ALTER TABLE campaigns ADD owner_id INT default 0 COMMENT 'Owner id of compaings';
ALTER TABLE adnumbers ADD user_id INT default 0 COMMENT 'Owner id of adnumbers';

CREATE TABLE IF NOT EXISTS cron_settings (
`id` int(11) NOT NULL auto_increment,
`action` varchar(255) NOT NULL COMMENT '',
`user_id` INTEGER NOT NULL COMMENT 'owner of setting',
`name` varchar(255) NOT NULL COMMENT 'Name of setting',
`description` BLOB COMMENT 'Setting comment',
`target_id` INTEGER NOT NULL COMMENT 'object ID, -1 all in class',
`target_class` varchar(255) NOT NULL COMMENT 'Object class',
`to_target_id` INTEGER NOT NULL COMMENT 'object ID, -1 all in class',
`to_target_class` varchar(255) NOT NULL COMMENT 'Object class',
`periodic_type` INTEGER DEFAULT 0 COMMENT 'type of periodic',
`to_do_time` TIME,
`repeat_forever` INTEGER DEFAULT 0,
`priority` INTEGER DEFAULT 0,
`to_do_times` INTEGER,
`valid_from` datetime,
`valid_till` datetime,
`created_at` datetime NOT NULL,
`updated_at` datetime NOT NULL,
PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE IF NOT EXISTS cron_actions (
`id` int(11) NOT NULL auto_increment,
`cron_setting_id` INTEGER NOT NULL COMMENT 'setting ID',
`attempts` INTEGER DEFAULT 0 COMMENT 'Provides for retries, but still fail eventually.',
`locked_by` varchar(255)  COMMENT 'Who is working on this object (if locked)',
`last_error` BLOB COMMENT 'reason for last failure',
`handler` varchar(255) COMMENT 'YAML-encoded string of the object that will do work',
`run_at` datetime COMMENT 'When to run. Could be Time.now for immediately, or sometime in the future.',
`locked_at` datetime COMMENT 'Set when a client is working on this object',
`failed_at` datetime COMMENT 'Set when all retries have failed (actually, by default, the record is deleted instead)',
`created_at` datetime NOT NULL,
`updated_at` datetime NOT NULL,
PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE ivrs ADD user_id INT default 0 COMMENT 'ID of the user who owns ivr';
ALTER TABLE ivr_timeperiods ADD user_id INT default 0 COMMENT 'ID of the user who owns ivr_timeperiods';
ALTER TABLE ivr_voices ADD user_id INT default 0 COMMENT 'ID of the user who owns ivr_voices';
ALTER TABLE ivr_sound_files ADD user_id INT default 0 COMMENT 'ID of the user who owns ivr_sound_files';

CREATE TABLE `quickforwards_rules` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL              COMMENT 'Rule name',
  `user_id` INTEGER                         COMMENT 'Foreign key to users table',
  `rule_regexp` varchar(255) NOT NULL       COMMENT 'Regexp rule to find dids.did',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE users ADD quickforwards_rule_id INT default 0 COMMENT 'User quickforwards rule ID';

ALTER TABLE pbxfunctions ADD allow_resellers INT default 1 COMMENT 'Pbxfunction allow use reseller';

ALTER TABLE users ADD currency_id INT default 1 COMMENT 'User default currency ID';

ALTER TABLE pbxfunctions ADD user_id INT default 0 COMMENT 'ID of the user who owns pbxfunction';
ALTER TABLE dialplans ADD user_id INT default 0 COMMENT 'ID of the user who owns dialplan';

ALTER TABLE locations ADD user_id INT default 0 COMMENT 'ID of the user who owns location';

update cardgroups SET tell_balance_in_currency = (SELECT name from currencies order by id asc limit 1);
ALTER TABLE cardgroups ADD tell_balance_in_currency varchar(5) default "" COMMENT 'cardgroups tell balance in currency?';

ALTER TABLE cardgroups ADD tell_cents boolean default false COMMENT 'should allow cardgroups tell censt?';

ALTER TABLE users ADD own_providers INT default 0 COMMENT 'should allow provider to have own providers?';

INSERT IGNORE INTO acc_rights(name, nice_name, permission_group) VALUES ('cli_ivr', 'IVR', 'CLI');
ALTER TABLE devicecodecs ADD priority INT default 0 COMMENT 'codec priority for device';
ALTER TABLE providercodecs ADD priority INT default 0 COMMENT 'codec priority for provider';

ALTER TABLE devices ADD enable_mwi INT default 0 COMMENT 'MWI enable for device';

ALTER TABLE providers ADD hidden INT default 0 COMMENT 'Provider hidden status';

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_user_warning_email_hour', '-1', '0');

ALTER TABLE users ADD warning_email_hour INT default -1 COMMENT 'warning balance email sending at hour';

INSERT IGNORE INTO acc_rights
(name,                 nice_name,             permission_group) VALUES
('user_manage',        'Manage_Users',       'User'),
('device_manage',      'Manage_Devices',     'Device'),
('see_financial_data', 'See_Financial_Data', 'Data'),
('vouchers_manage',    'Manage_Vouchers',    'Vouchers'),
('services_manage',    'Manage_Services',    'Services'),
('invoices_manage',    'Manage_Invoices',    'Invoices'),
('payments_manage',    'Manage_Payments',    'Payments');

update role_rights
    left join roles on (role_rights.role_id = roles.id)
    left join rights on (role_rights.right_id = rights.id)
  set permission = 1
where roles.name = "accountant" and rights.controller = "services" and rights.action = "subscriptions";

update role_rights
    left join roles on (role_rights.role_id = roles.id)
    left join rights on (role_rights.right_id = rights.id)
  set permission = 1
where roles.name = "accountant" and rights.controller = "stats" and rights.action = "providers";

update role_rights
    left join roles on (role_rights.role_id = roles.id)
    left join rights on (role_rights.right_id = rights.id)
  set permission = 1
where roles.name = "accountant" and rights.controller = "stats" and rights.action = "system_stats";

ALTER TABLE acc_groups ADD COLUMN only_view TINYINT(1)  NOT NULL DEFAULT 0 COMMENT 'accountants can only view data';

ALTER TABLE devices ADD server_id INT NOT NULL default 1 COMMENT 'points to servers.server_id';

ALTER TABLE users ADD hide_destination_end TINYINT default -1;
ALTER TABLE sms_providers ADD sms_from varchar(255) default '' COMMENT 'SMS source address, sender ID';

ALTER TABLE adnumbers ADD INDEX number_index(number);
ALTER TABLE adnumbers ADD INDEX campaign_id_index(campaign_id);
CREATE TABLE `call_logs` (`id` bigint(20) NOT NULL auto_increment, `uniqueid` varchar(20) NOT NULL,`log` blob, PRIMARY KEY  (`id`),  KEY `uniqueid_index` (`uniqueid`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
ALTER TABLE devices ADD save_call_log TINYINT default 0 COMMENT 'Save call log';
ALTER TABLE invoices ADD COLUMN comment BLOB COMMENT 'Comment on invoice';

ALTER TABLE devices ADD fake_ring TINYINT default 0 COMMENT 'Fake ring for this device?';

CREATE TABLE `cc_gmps` (
  `id` int(11) NOT NULL auto_increment,
  `cardgroup_id` int(11) NOT NULL,
  `prefix` varchar(255) NOT NULL,
  `percent` int(11) NOT NULL default '100',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8; 

#=================== MOR9 starts from here and up ===========

ALTER TABLE taxes ADD compound_tax tinyint(4) default 1 COMMENT 'is this tax compound';
ALTER TABLE providers ADD COLUMN  `reg_line` varchar(255) default NULL;

ALTER TABLE actions ADD INDEX `user_id_index`(`user_id`);
ALTER TABLE actions ADD INDEX `target_id_index`(`target_id`);

INSERT INTO emails (name, template, date_created, subject, body) VALUES ('prepaid_no_balance_block', 1, NOW(),'Account blocked',"Account was blocked because of insufficient balance\nUser: <%= full_name %>\nBalance: <%=balance %>");

ALTER TABLE actions ADD COLUMN  `data3` varchar(255) default NULL;
ALTER TABLE actions ADD COLUMN  `data4` varchar(255) default NULL;

ALTER TABLE c2c_invoices ADD tax_id int(11) default NULL COMMENT 'Tax for invoice';
ALTER TABLE invoices ADD tax_id int(11) default NULL COMMENT 'Tax for invoice';

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Hide_HELP_banner', '0', '0');

CREATE TABLE `flatrate_data` (
  `id`              INTEGER      NOT NULL auto_increment,
  `year_month`      VARCHAR(255) NOT NULL COMMENT 'Marks year and month for which minutes are counted',
  `minutes`         INTEGER      NOT NULL COMMENT 'How many minutes user has already used',
  `subscription_id` INTEGER      NOT NULL COMMENT 'Foreign key to subscriptions table',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `flatrate_destinations` (
  `id`             INTEGER NOT NULL auto_increment,
  `service_id`     INTEGER NOT NULL COMMENT 'Foreign key to services table',
  `destination_id` INTEGER NOT NULL COMMENT 'Foreign key to destination table',
  `active`        TINYINT NOT NULL COMMENT '1 - This destination is included into flatrate service, 0 - destination is excluded',
  INDEX service_id_index (`service_id`),
  INDEX destination_id_index (`destination_id`),
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `conflines` (name, value, owner_id) VALUES ('reCAPTCHA_enabled', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('reCAPTCHA_private_key', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('reCAPTCHA_public_key', '', '0');

# -------------------------- Till this line added to install script ------------------------------------------------

ALTER TABLE invoices ADD number_type TINYINT default 1 COMMENT 'invoice number format type';

ALTER TABLE recordings ADD local TINYINT default 1 COMMENT 'Is recording on local server?';

ALTER TABLE devices ADD record_forced TINYINT default 0 COMMENT 'Force recording for this device?';

ALTER TABLE recordings ADD dst_user_id int(11) default 0 COMMENT 'User which received call';
ALTER TABLE recordings ADD visible_to_user tinyint(4) default 1 COMMENT 'Can user see it?';
ALTER TABLE recordings ADD uniqueid varchar(30) default '' COMMENT 'Name of recording';

ALTER TABLE acc_rights ADD permission_group varchar(50) NOT NULL default '' COMMENT 'Permission group'

INSERT INTO `acc_rights`(`id`,`name`, `nice_name`, `permission_group`) VALUES 
('1', 'user_create_opt_1', 'User_Password', 'User'),
('2', 'user_create_opt_2', 'User_Type', 'User'),
('3', 'user_create_opt_3', 'User_Lrc', 'User'),
('4', 'user_create_opt_4', 'User_Tariff', 'User'),
('5', 'user_create_opt_5', 'User_Balance', 'User'),
('6', 'user_create_opt_6', 'User_Payment_type', 'User'),
('7', 'user_create_opt_7', 'User_Call_limit', 'User'),
('8', 'device_edit_opt_1', 'Device_Extension', 'Device'),
('9', 'device_edit_opt_2', 'Device_Autentication', 'Device'),
('10', 'device_edit_opt_3', 'Decive_CallerID_Name', 'Device'),
('11', 'device_edit_opt_4', 'Device_CallerID_Number', 'Device'),
('12', 'Device_PIN', 'Device_PIN', 'Device'),
('13', 'Callingcard_PIN', 'Callingcard_PIN', 'Callingcard'),
('14', 'Device_Password', 'Device_Password', 'Device'),
('15', 'VoiceMail_Password', 'VoiceMail_Password', 'Device'),
('16', 'User_create', 'User_create', 'User'),
('17', 'Device_create', 'Device_create', 'Device'),
('18', 'Callingcard_manage', 'Callingcard_manage', 'Callingcard'),
('19', 'Tariff_manage', 'Tariff_manage', 'Tariff'),
('20', 'manage_dids_opt_1', 'Manage_DID', 'DID'),
('21', 'manage_subscriptions_opt_1', 'Manage_subscriptions', 'Subscription');


ALTER TABLE recordings ADD size FLOAT NOT NULL default 0 COMMENT 'Recording file size';

UPDATE invoices LEFT JOIN users ON (invoices.user_id = users.id) SET invoices.invoice_type = CASE WHEN users.postpaid = 1 THEN 'postpaid' ELSE 'prepaid' END
UPDATE c2c_invoices LEFT JOIN users ON (c2c_invoices.user_id = users.id) SET c2c_invoices.invoice_type = CASE WHEN users.postpaid = 1 THEN 'postpaid' ELSE 'prepaid' END


ALTER TABLE users ADD acc_group_id INTEGER NOT NULL default 0;

ALTER TABLE actions ADD target_type VARCHAR(255) default "" COMMENT 'target type user/device/cardgroup...';
ALTER TABLE actions ADD target_id   INTEGER      default NULL COMMENT 'id of target ';

CREATE TABLE `acc_groups` (
  `id`   INTEGER      NOT NULL        auto_increment,
  `name` varchar(255) NOT NULL UNIQUE default ""     COMMENT 'Accountant group name',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `acc_rights` (
  `id`        INTEGER      NOT NULL        AUTO_INCREMENT,
  `name`      VARCHAR(255) NOT NULL UNIQUE DEFAULT ""     COMMENT 'Accountant right name',
  `nice_name` VARCHAR(255) NOT NULL        DEFAULT ""     COMMENT 'Accountant right name to be shown in translation',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `acc_group_rights` (
  `id`           INTEGER NOT NULL auto_increment,
  `acc_group_id` INTEGER NOT NULL COMMENT 'Accountant group id',
  `acc_right_id` INTEGER NOT NULL COMMENT 'Accountant right id',
  `value`        TINYINT NOT NULL COMMENT 'Role right value ',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO acc_rights(`name`, `nice_name`) VALUES
  ('user_create_opt_1', 'User_Password'),
  ('user_create_opt_2', 'User_Type'),
  ('user_create_opt_3', 'User_Lrc'),
  ('user_create_opt_4', 'User_Tariff'),
  ('user_create_opt_5', 'User_Balance'),
  ('user_create_opt_6', 'User_Payment_type'), 
  ('user_create_opt_7', 'User_Call_limit'),
  ('device_edit_opt_1', 'Device_Extension'),
  ('device_edit_opt_2', 'Device_Autentication'),
  ('device_edit_opt_3', 'Decive_CallerID_Name'),
  ('device_edit_opt_4', 'Device_CallerID_Number'),
  ('Device_PIN', 'Device_PIN'),
  ('Callingcard_PIN', 'Callingcard_PIN'), 
  ('Device_Password', 'Device_Password'), 
  ('VoiceMail_Password', 'VoiceMail_Password'), 
  ('User_create', 'User_create'), 
  ('Device_create', 'Device_create'), 
  ('Callingcard_manage', 'Callingcard_manage'), 
  ('Tariff_manage', 'Tariff_manage');

ALTER TABLE ccorders ADD tax_percent double default '0';

ALTER TABLE invoices ADD invoice_type varchar(20) default NULL;
ALTER TABLE c2c_invoices ADD invoice_type varchar(20) default NULL;

UPDATE invoices LEFT JOIN users ON (invoices.user_id = users.id) SET invoices.invoice_type = CASE WHEN users.postpaid = 1 THEN 'postpaid' ELSE 'prepaid' END;
UPDATE c2c_invoices LEFT JOIN users ON (c2c_invoices.user_id = users.id) SET c2c_invoices.invoice_type = CASE WHEN users.postpaid = 1 THEN 'postpaid' ELSE 'prepaid' END;


ALTER TABLE users ADD invoice_zero_calls TINYINT NOT NULL default 1;

ALTER TABLE cardgroups DROP COLUMN tax_1, DROP COLUMN tax_2, DROP COLUMN tax_3, DROP COLUMN tax_4;


INSERT INTO `conflines` (name, value, owner_id) VALUES ('Show_logo_on_register_page', '0', '0');

INSERT INTO emails (name, template, date_created, subject, body) VALUES ('warning_balance_email', 1, NOW(),'Warning',"Balance: <%=balance %>");


ALTER TABLE cardgroups ADD tax_id INTEGER NOT NULL default 0; 
ALTER TABLE users ADD tax_id INTEGER NOT NULL default 0;

CREATE INDEX destinations_direction_code_index ON destinations(direction_code);
CREATE INDEX directions_code_index ON directions (code);

CREATE INDEX cards_number_index ON cards(number);
CREATE INDEX cards_pin_index ON cards(pin);

CREATE TABLE `terminators` (
  `id` int(11)        NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default "",
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE providers ADD terminator_id INTEGER NOT NULL default 0;


ALTER TABLE calls ADD real_duration double NOT NULL default 0 COMMENT 'exact duration';
ALTER TABLE calls ADD real_billsec double NOT NULL default 0 COMMENT 'exact billsec';

CREATE TABLE `cc_invoices` (
  `id`             INTEGER      NOT NULL AUTO_INCREMENT,
  `payment_id`     INTEGER                              COMMENT 'Foreign key to payments table',
  `ccorder_id`     INTEGER      NOT NULL                COMMENT 'Foreign key to ccorders table',
  `owner_id`       INTEGER      NOT NULL DEFAULT '0'    COMMENT 'Foreign key to users table describes payment owner',
  `number`         VARCHAR(255) NOT NULL                COMMENT 'Payment number',
  `email`          VARCHAR(50)  NOT NULL DEFAULT ''     COMMENT 'Client email address',
  `sent_email`     TINYINT      NOT NULL DEFAULT '0',
  `sent_manually`  TINYINT      NOT NULL DEFAULT '0',
  `paid`           TINYINT      NOT NULL DEFAULT '0',
  `created_at`     DATETIME     NOT NULL,
  `paid_date`      DATETIME              DEFAULT NULL,
  INDEX owner_id_index (`owner_id`),
  PRIMARY KEY (`id`)
)
ENGINE = InnoDB CHARACTER SET utf8;


ALTER TABLE `calls` DROP INDEX `7`, DROP INDEX `3`, DROP INDEX `2`, DROP INDEX `9`, DROP INDEX `4`, DROP INDEX `5`, DROP INDEX `id`, DROP INDEX `calldate_2`, DROP INDEX `calldate_3`, DROP INDEX `dst`, DROP INDEX `dst_2`;

ALTER TABLE calls ADD originator_ip varchar(20) default NULL;
ALTER TABLE calls ADD terminator_ip varchar(20) default NULL;

ALTER TABLE users ADD warning_email_active TINYINT NOT NULL default 0;
ALTER TABLE users ADD warning_email_sent TINYINT NOT NULL default 0;
ALTER TABLE users ADD warning_email_balance double NOT NULL default '0';

CREATE TABLE `taxes` (
  `id`             INTEGER      NOT NULL AUTO_INCREMENT,
  `tax1_enabled`   TINYINT      NOT NULL DEFAULT '0' COMMENT 'Shows if tax is enabled',
  `tax2_enabled`   TINYINT      NOT NULL DEFAULT '0'COMMENT 'Shows if tax is enabled',
  `tax3_enabled`   TINYINT      NOT NULL DEFAULT '0'COMMENT 'Shows if tax is enabled',
  `tax4_enabled`   TINYINT      NOT NULL DEFAULT '0'COMMENT 'Shows if tax is enabled',
  `tax1_name`      varchar(255) NOT NULL DEFAULT '' COMMENT 'Tax name',
  `tax2_name`      varchar(255) NOT NULL DEFAULT '' COMMENT 'Tax name',
  `tax3_name`      varchar(255) NOT NULL DEFAULT '' COMMENT 'Tax name',
  `tax4_name`      varchar(255) NOT NULL DEFAULT '' COMMENT 'Tax name',
  `total_tax_name` varchar(255) NOT NULL DEFAULT '' COMMENT 'Name of total tax. Sum of all taxes', 
  `tax1_value`     FLOAT        NOT NULL DEFAULT 0  COMMENT 'Tax percentage. E.g. 19.5',
  `tax2_value`     FLOAT        NOT NULL DEFAULT 0  COMMENT 'Tax percentage. E.g. 19.5',
  `tax3_value`     FLOAT        NOT NULL DEFAULT 0  COMMENT 'Tax percentage. E.g. 19.5',
  `tax4_value`     FLOAT        NOT NULL DEFAULT 0  COMMENT 'Tax percentage. E.g. 19.5',
  PRIMARY KEY (`id`)
)
ENGINE = InnoDB CHARACTER SET utf8;

INSERT INTO emails (name, template, date_created, subject, body) VALUES ('Calling_Cards_data_to_PayPal', 1, NOW(),'Calling_Cards_data_to_PayPal'," <table>
	<tr>
	    <th><%= _('Number')%></th>
	    <th><%= _('PIN') %></th>
	    <th><%= _('Price') %></th>
	</tr>
    <% i = 0 %>
    <% for card in cards %>
	<tr >   
	    <td align='center'>
		 <%= card.number%>
	    </td>
	    <td align='center'>
    		 <%= card.pin %> 
	    </td>
	    <td align='center'>
    		 <%= card.cardgroup.price %> 
	    </td>
	</tr>
	<% i += 1%>
    <%end%>
     </table>");






#-------------------- SMS ---------------------------------

CREATE TABLE `sms_providers` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `login` varchar(255) default NULL,
  `password` varchar(255) default NULL,
  `api_id` int(11) default NULL,
  `priority` int(11) default NULL,
  `sms_tariff_id` int(11) default NULL,
  `provider_type` varchar(255) default NULL,
  `sms_provider_domain` varchar(255) default NULL,
  `use_subject` varchar(255) default NULL,
  `sms_subject` varchar(255) default NULL,
  `sms_email_wait_time` varchar(255) default '0',
  `wait_for_good_email` int(11) default '0',
  `email_good_keywords` varchar(255) default NULL,
  `wait_for_bad_email` int(11) default '0',
  `email_bad_keywords` varchar(255) default NULL,
  `time_out_charge_user` int(11) default '0',
  `nan_keywords_charge_user` int(11) default '0',
  `pay_sms_receiver` int(11) default '0',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



CREATE TABLE `sms_lcrproviders` (
  `id` INT(11)  NOT NULL AUTO_INCREMENT,
  `sms_lcr_id`  INT(11)  NOT NULL,
  `sms_provider_id`  INT(11)  NOT NULL,
  `active`  INT(11)  default '1',
  `priority`  INT(11)  default '1',
  PRIMARY KEY(`id`)
) ENGINE = InnoDB CHARACTER SET utf8;


CREATE TABLE `sms_lcrs` (
  `id` INT(11)  NOT NULL AUTO_INCREMENT,
  `name`  varchar(255) default NULL,
  `order`  varchar(255) default 'price',
  PRIMARY KEY(`id`)
) ENGINE = InnoDB CHARACTER SET utf8;


CREATE TABLE `sms_messages` (
  `id` INT(11)  NOT NULL AUTO_INCREMENT,
  `sending_date` datetime DEFAULT NULL,
  `status_code`  varchar(255) default NULL,
  `provider_id` INT(11),
  `provider_rate` double default '0',
  `provider_price` double default '0',
  `user_id` INT(11),
  `user_rate` double default '0',
  `user_price` double default '0',
  `reseller_id` INT(11)  default '0',
  `reseller_rate` double default '0',
  `reseller_price` double default '0',
  `prefix`  varchar(255) default NULL,
  `number`  varchar(255) default NULL,
  `clickatell_message_id`  varchar(255) default NULL,
  PRIMARY KEY(`id`)
) ENGINE = InnoDB CHARACTER SET utf8;


CREATE TABLE `sms_tariffs` (
  `id` int(11) NOT NULL auto_increment,
  `name`  VARCHAR(255),
  `tariff_type`  VARCHAR(255),
  `owner_id` INT(11)  default '0',
  `currency`  VARCHAR(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `sms_rates` (
  `id` int(11) NOT NULL auto_increment,
  `prefix` varchar(255) default NULL,
  `price` double NOT NULL default '0',
  `sms_tariff_id`  int(11),
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;




INSERT INTO `conflines` (name, value, owner_id) VALUES ('Show_logo_on_register_page', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Email_Callback_Pop3_Server', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Email_Callback_Login', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Email_Callback_Password', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Web_Callback_Server', '1', '0');

ALTER TABLE recordings ADD user_id INT NOT NULL default 0;
ALTER TABLE recordings ADD path varchar(255) NOT NULL default "";
ALTER TABLE recordings ADD enabled TINYINT  NOT NULL default 1;
ALTER TABLE recordings ADD forced TINYINT  NOT NULL default 1;
ALTER TABLE recordings ADD deleted TINYINT  NOT NULL default 0;
ALTER TABLE recordings ADD send_time DATETIME default NULL;
ALTER TABLE recordings ADD comment varchar(255) NOT NULL default "";


ALTER TABLE devices ADD recording_to_email TINYINT NOT NULL default 0;
ALTER TABLE devices ADD recording_keep TINYINT NOT NULL default 0;
ALTER TABLE devices ADD recording_email varchar(50) default NULL;

ALTER TABLE cards ADD callerid varchar(30) default NULL;

ALTER TABLE users ADD recording_enabled TINYINT NOT NULL default 0;
ALTER TABLE users ADD recording_forced_enabled TINYINT NOT NULL default 0;
ALTER TABLE users ADD recordings_email varchar(50) default NULL;
ALTER TABLE users ADD recording_hdd_quota INT NOT NULL default 100;

UPDATE conflines SET value2 = 1  WHERE conflines.name = 'Tax_1';

ALTER TABLE users ADD block_conditional_use tinyint(4) default 0;

ALTER TABLE vouchers ADD active tinyint(4) default 1;

ALTER TABLE lcrproviders ADD percent int(11) default 0;

ALTER TABLE cards ADD owner_id int(11) default 0;
ALTER TABLE cardgroups ADD owner_id int(11) default 0;

ALTER TABLE devices ADD latency double default 0;
ALTER TABLE devices ADD grace_time int(11) default 0;

ALTER TABLE devices ADD faststart enum('no','yes') default 'yes';
ALTER TABLE devices ADD h245tunneling enum('no','yes') default 'yes';

ALTER TABLE users ADD block_at_conditional tinyint(4) default 15;

ALTER TABLE callerids ADD email_callback int(11) default '0';

ALTER TABLE phonebooks ADD card_id int(11) NOT NULL default 0;
ALTER TABLE phonebooks ADD speeddial varchar(50);
ALTER TABLE phonebooks ADD updated_at datetime;

ALTER TABLE users ADD block_at date default '2008-01-01';

ALTER TABLE `callerids` ADD banned int(4)  default 0;
ALTER TABLE `callerids` ADD created_at datetime NOT NULL;
ALTER TABLE `callerids` ADD updated_at datetime NOT NULL;
ALTER TABLE `callerids` ADD ivr_id int(11)  default 0;
ALTER TABLE `callerids` ADD comment BLOB  default NULL;

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Banned_CLIs_default_IVR_id', '0', '0');

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Tax_1_Value', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Tax_2_Value', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Tax_3_Value', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Tax_4_Value', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Total_Tax_Value', '0', '0');

INSERT INTO `conflines` (name, value, owner_id, value2) VALUES ('Tax_1', 'VAT', '0', '1');
INSERT INTO `conflines` (name, value, owner_id, value2) VALUES ('Tax_2', '', '0', '0');
INSERT INTO `conflines` (name, value, owner_id, value2) VALUES ('Tax_3', '', '0', '0');
INSERT INTO `conflines` (name, value, owner_id, value2) VALUES ('Tax_4', '', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Total_tax_name', 'Total Tax', '0');

ALTER TABLE `cardgroups` ADD tax_1 double  default 0;
ALTER TABLE `cardgroups` ADD tax_2 double  default 0;
ALTER TABLE `cardgroups` ADD tax_3 double  default 0;
ALTER TABLE `cardgroups` ADD tax_4 double  default 0;

ALTER TABLE `users` ADD tax_1 double  default 0;
ALTER TABLE `users` ADD tax_2 double  default 0;
ALTER TABLE `users` ADD tax_3 double  default 0;
ALTER TABLE `users` ADD tax_4 double  default 0;


ALTER TABLE `users` ADD generate_invoice tinyint(4)  default '1';

ALTER TABLE `servers` ADD gateway_active tinyint(4)  default 0;

CREATE TABLE `gateways` (
  `id` int(10) unsigned NOT NULL auto_increment COMMENT 'Unique ID',
  `setid` int(11) NOT NULL default '1' COMMENT 'Destination Set ID',
  `destination` varchar(192) NOT NULL default 'sip:' COMMENT 'Destination SIP Address',
  `description` varchar(255) COMMENT 'Description for this Destination',
  `server_id` unsigned int(10) NOT NULL,	
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;




# ----------- MOR 0.7 ------------------------


ALTER TABLE `campaigns` ADD callerid varchar(100)  default '';

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Webmoney_skip_prerequest', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Crash_log_file', '/tmp/mor_crash.log', '0');

ALTER TABLE `users` ADD call_center_agent INT(11)  default '0';

CREATE TABLE `lcr_partials` (
 `id`  INT(11)  NOT NULL AUTO_INCREMENT,
 `main_lcr_id` int(11) NOT NULL,
 `prefix` varchar(255) NOT NULL,
 `lcr_id` int(11) NOT NULL,
 PRIMARY KEY(`id`)
) ENGINE = InnoDB CHARACTER SET utf8;

ALTER TABLE hangupcausecodes CHANGE description description BLOB NOT NULL;


#-------------------- Backup ---------------------------------
CREATE TABLE `backups` (
  `id` INT(11)  NOT NULL AUTO_INCREMENT,
  `backuptime`  varchar(255) default NULL,
  `comment`   varchar(255) default NULL,
  `backuptype`  varchar(255) default NULL,
  PRIMARY KEY(`id`)
) ENGINE = InnoDB CHARACTER SET utf8;


INSERT INTO `conflines` (name, value, owner_id) VALUES ('Backup_Folder', '/usr/local/backups/mor', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Backup_number', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Backup_disk_space', '10', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Backup_shedule', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Backup_month', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Backup_month_day', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Backup_week_day', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Backup_hour', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Backup_minute', '1', '0');

#-------------------------------

INSERT INTO `conflines` (name, value, owner_id) VALUES ('CCShop_show_values_without_VAT_for_user', '1', '0');


ALTER TABLE `emails` ADD owner_id INT(11)  default '0';
ALTER TABLE `emails` ADD callcenter INT(11)  default '0';
ALTER TABLE `actions` ADD processed INT(11)  default '0';

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Show_Full_Src', '1', '0');

ALTER TABLE activecalls ADD localized_dst varchar(100) default NULL;

ALTER TABLE `actions` ADD processed INT(11)  default '0';

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Exception_Support_Email', 'support@kolmisoft.com', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Exception_Send_Email', '1', '0');

alter table callflows add data3 int(11) default '1';
alter table callflows add data4 varchar(255) default null;

ALTER TABLE `c2c_invoices` ADD sent_email INT(11)  default '0';
ALTER TABLE `c2c_invoices` ADD sent_manually INT(11)  default '0';
ALTER TABLE `invoices` ADD sent_email INT(11)  default '0';
ALTER TABLE `invoices` ADD sent_manually INT(11)  default '0';

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Invoice_Balance_Line', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Fax2Email_Folder', '', '0');

ALTER TABLE `calls` ADD did_id INT(11) default NULL;

ALTER TABLE `emails` ADD format varchar(255) default 'html';

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Email_Pop3_server', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Email_port', '25', '0');

UPDATE calls, dids
SET calls.did_id = dids.id
where calls.localized_dst = dids.did 

ALTER TABLE `c2c_invoicedetails` ADD quantity INT(11) default '0';

#-------------------- IVR ----------------------------------

CREATE TABLE IF NOT EXISTS `ivr_actions` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `ivr_block_id` int(11) NOT NULL,
  `data1` varchar(255) default NULL,
  `data2` varchar(255) default NULL,
  `data3` varchar(255) default NULL,
  `data4` varchar(255) default NULL,
  `data5` varchar(255) default NULL,
  `data6` varchar(255) default NULL,
  `order` int(11) default NULL,
  PRIMARY KEY  (`id`)
)ENGINE = InnoDB CHARACTER SET utf8;


CREATE TABLE IF NOT EXISTS `ivr_extensions` (
  `id` INT(11)  NOT NULL AUTO_INCREMENT,
  `exten` VARCHAR(255)  NOT NULL,
  `goto_ivr_block_id` INT(11)  NOT NULL,
  `ivr_block_id` INT(11)  NOT NULL,
  PRIMARY KEY(`id`)
)
ENGINE = InnoDB CHARACTER SET utf8;


CREATE TABLE IF NOT EXISTS `ivr_blocks` (
  `id` INT(11)  NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255)  NOT NULL,
  `ivr_id` INT(11),
  `timeout_response` INT(11) DEFAULT 10,
  `timeout_digits` INT(11) DEFAULT 3,
  PRIMARY KEY(`id`)
)
ENGINE = InnoDB CHARACTER SET utf8;

CREATE TABLE IF NOT EXISTS `ivrs` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `start_block_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`)
)
ENGINE = InnoDB CHARACTER SET utf8;

CREATE TABLE IF NOT EXISTS `ivr_timeperiods` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `start_hour` int(11) NOT NULL,
  `end_hour` int(11) NOT NULL,
  `start_minute` int(11) NOT NULL,
  `end_minute` int(11) NOT NULL,
  `start_weekday` varchar(3) default NULL,
  `end_weekday` varchar(3) default NULL,
  `start_day` int(11) default NULL,
  `end_day` int(11) default NULL,
  `start_month` int(11) default NULL,
  `end_month` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE = InnoDB CHARACTER SET utf8;


CREATE TABLE IF NOT EXISTS `ivr_sound_files` (
  `id` int(11) NOT NULL auto_increment,
  `ivr_voice_id` varchar(255) NOT NULL,
  `path` varchar(255) NOT NULL,
  `description` varchar(255) NOT NULL,
  `created_at` datetime default NULL,
  `size` int(11) default '0',
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `ivr_voices` (
 `id` int(11) NOT NULL auto_increment,
  `voice` varchar(255) NOT NULL,
  `description` varchar(255) NOT NULL,
  `created_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE INDEX hgcause ON calls(hangupcause);
CREATE INDEX user_id_index ON subscriptions(user_id);
CREATE INDEX user_id_index ON calls(user_id);

ALTER TABLE providers ADD register INT(1) DEFAULT 0;
ALTER TABLE providers ADD reg_extension varchar(30) DEFAULT NULL;

CREATE INDEX disposition USING BTREE ON calls(disposition);

INSERT INTO emails (name, template, date_created, subject, body) VALUES ('invoices', 1, NOW(),'Invoices',"Invoices are attached.");
INSERT INTO emails (name, template, date_created, subject, body) VALUES ('c2c_invoices', 1, NOW(),'Invoices',"Invoices are attached.");


ALTER TABLE users ADD cyberplat_active INT(1) DEFAULT 0;
CREATE INDEX periodstart USING BTREE ON invoices(period_start);

ALTER TABLE calls ADD did_provider_id int(11) default 0;

# --- backup ---

ALTER TABLE servers ADD ssh_username varchar(255) default 'root';
ALTER TABLE servers ADD ssh_secret varchar(255) default NULL;
ALTER TABLE servers ADD ssh_port int(11) default '22';

# --- sms ---

ALTER TABLE users ADD sms_tariff_id int(11) default NULL;
ALTER TABLE users ADD sms_lcr_id int(11) default NULL;
ALTER TABLE users ADD sms_service_active int(11) default '0';

#------------

CREATE INDEX dt USING BTREE ON ratedetails(daytype);

CREATE INDEX name USING BTREE ON currencies(name);

ALTER TABLE dids ADD call_limit int(11) default '0';

ALTER TABLE activecalls ADD did_id int(11) default NULL;
ALTER TABLE activecalls ADD user_id int(11) default NULL;
ALTER TABLE activecalls ADD owner_id int(11) default NULL;

ALTER TABLE locationrules ADD lcr_id int(11) default NULL;
ALTER TABLE locationrules ADD tariff_id int(11) default NULL;

INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_dtmfmode', 'rfc2833', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_works_not_logged', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_location_id', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_ani', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_istrunk', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_record', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_call_limit', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_cid_name', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_cid_number', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_host', 'dynamic', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_port', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_canreinvite', 'no', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_nat', 'yes', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_qualify', '1000', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_qualify_time', '2000', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_callgroup', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_pickupgroup', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_voicemail_active', null, '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_voicemail_box', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_voicemail_box_email', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_voicemail_box_password', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_fromuser', null, '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_fromdomain', null, '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_trustrpid', 'no', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_sendrpid', 'no', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_t38pt_udptl', 'no', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_promiscredir', 'no', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_progressinband', 'no', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_videosupport', 'no', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_allow_duplicate_calls', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_tell_balance', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_tell_time', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_tell_rtime_when_left', '60', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_repeat_rtime_every', '60', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_permits', '0.0.0.0/0.0.0.0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_type', 'SIP', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_timeout', '60', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_ipaddr', '', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_regseconds', 'no', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_insecure', null, '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_process_sipchaninfo', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_alaw', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_ulaw', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_g723', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_g726', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_g729', '1', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_gsm', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_ilbc', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_lpc10', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_speex', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_adpcm', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_slin', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_h261', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_h263', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_h263p', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_h264', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_jpeg', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Default_device_codec_png', '0', '0');


ALTER TABLE users ADD call_limit int(11) default '0';
ALTER TABLE devices ADD call_limit int(11) default '0';
ALTER TABLE providers ADD call_limit int(11) default '0';


ALTER TABLE providers ADD COLUMN interpret_noanswer_as_failed tinyint(4) DEFAULT 0;
ALTER TABLE providers ADD COLUMN interpret_busy_as_failed tinyint(4) DEFAULT 0;


ALTER TABLE servers ADD port int(11) default '5060';

ALTER TABLE c2c_calls ADD notice_email_send int(11) default '0';
ALTER TABLE c2c_campaigns ADD send_email_after int(11) default '60';

ALTER TABLE users ADD c2c_call_price double default NULL;

CREATE TABLE `c2c_invoices` (
  `id` int(11) NOT NULL auto_increment,
  `user_id` int(11) NOT NULL,
  `period_start` date NOT NULL COMMENT 'when start to bill',
  `period_end` date NOT NULL COMMENT 'till when bill',
  `issue_date` date NOT NULL COMMENT 'when invoice issued',
  `paid` tinyint(4) NOT NULL default '0',
  `paid_date` datetime default NULL,
  `price` double NOT NULL default '0',
  `price_with_vat` double NOT NULL default '0',
  `payment_id` int(11) default NULL,
  `number` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;


CREATE TABLE `c2c_invoicedetails` (
  `id` int(11) NOT NULL auto_increment,
  `c2c_invoice_id` int(11) default NULL,
  `c2c_campaign_id` int(11) default NULL,
  `name` varchar(255) default NULL,
  `total_calls` int(11) default NULL,
  `price` double default NULL,
  `invdet_type` tinyint(4) default '1',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;




INSERT INTO conflines (name, value) VALUES ("Google_Fullscreen", 0);
INSERT INTO conflines (name, value) VALUES ("Google_ReloadTime", 60);
INSERT INTO conflines (name, value) VALUES ("Google_Width", 800);
INSERT INTO conflines (name, value) VALUES ("Google_Height", 600);

CREATE TABLE `iplocations` (
  `id` int(11) NOT NULL auto_increment,
  `ip` varchar(255) NOT NULL,
  `latitude` float NOT NULL,
  `longitude` float NOT NULL,
  `country` varchar(255) default NULL,
  `city` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


ALTER TABLE devices ADD COLUMN allow_duplicate_calls int(11) DEFAULT 0;


ALTER TABLE c2c_campaigns ADD try_times int(11) default 3;
ALTER TABLE c2c_campaigns ADD pause_between_calls int(11) default 20;


ALTER TABLE services ADD quantity int(11) default 1;

INSERT INTO emails (name, template, date_created, subject, body) VALUES ('cyberplat_announce', 1,NOW(),'Cyberplat payment announce',"Thank you for using cyberplat.<br />
Company name: <%= company_name %><br />
Designation: VoIP<br />
URL: <%= url %><br />
Company_Email: <%= email%><br />
Amount+VAT: <%= amount %> <%= currency %><br />
Transaction date: <%= date %><br />
Authorization Code: <%= auth_code %><br />
Transaction Identifier <%= trans_id %><br />
Customer Name <%= customer_name %><br />
Operation Type: Balance Update<br />
Description: <%= description %>");


ALTER TABLE conflines ADD value2 blob default null;
INSERT INTO conflines (name, value) VALUES ("Cyberplat_Temporary_Directory", "/tmp/"); 
INSERT INTO conflines (name, value) VALUES ("Cyberplat_Test", 1); 
INSERT INTO conflines (name, value) VALUES ("Cyberplat_Transacton_Fee", 5); 
INSERT INTO conflines (name, value2) VALUES ("Cyberplat_Crap", "");

ALTER TABLE devices ADD COLUMN temporary_id integer DEFAULT NULL;
ALTER TABLE users ADD COLUMN temporary_id integer DEFAULT NULL;

INSERT INTO pbxfunctions (name, pf_type, context, extension, priority) VALUES ('Use Voucher',  'use_voucher', 'mor_pbxfunctions', 'use_voucher', 1);

CREATE INDEX ad1 USING BTREE ON adnumbers(status, campaign_id);


INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Albanian Lek', 'ALL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Algerian Dinar', 'DZD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Argentinian Peso', 'ARS', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Aruban Florin', 'AWG', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Australian Dollar', 'AUD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Austrian Schilling', 'ATS', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Bahraini Dinar', 'BHD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Bangladesh Taka', 'BDT', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Barbados Dollar', 'BBD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Belgian Franc', 'BEF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Belize Dollar', 'BZD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Bermuda Dollar', 'BMD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Bhutan Ngultrum', 'BTN', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Bolivian Boliviano', 'BOB', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Botswana Pula', 'BWP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Brazilian Real', 'BRL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('British Pound', 'GBP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Brunei Dollar', 'BND', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Bulgarian Lev', 'BGN', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Cambodian Riel', 'KHR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Canadian Dollar', 'CAD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Cape Verde Escudo', 'CVE', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Cayman Islands Dollar', 'KYD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('CFA Franc', 'BCEAO', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('CFA Franc', 'XOF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('CFA Franc', 'XAF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('CFA Franc', 'BEAC', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('CFP Franc', 'XPF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Chilean Peso', 'CLP', '0', '1');	
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Colombian Peso', 'COP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Comoros Franc', 'KMF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Costa Rican Colon', 'CRC', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Croatian Kuna', 'HRK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Cuban Peso', 'CUP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Cypriot Pound', 'CYP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Czech Koruna', 'CZK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Danish Krone', 'DKK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Djibouti Franc', 'DJF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Dominican Peso', 'DOP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Dutch Guilder', 'NLG', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('East Caribbean Dollar', 'XCD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Egyptian Pound', 'EGP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('El Salvador Colon', 'SVC', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Estonian Kroon', 'EEK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Ethiopian Birr', 'ETB', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Euro', 'EUR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Fiji Dollar', 'FJD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Finnish Markka', 'FIM', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('French Franc', 'FRF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Gambia Dalasi', 'GMD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('German Mark', 'DEM', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Ghanaian Cedi', 'GHC', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Gibraltar Pound', 'GIP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Greek Drachma', 'GRD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Guatemala Quetzal', 'GTQ', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Guinea Franc', 'GNF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Guyana Dollar', 'GYD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Haitian Gourde', 'HTG', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Honduras Lempira', 'HNL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Hong Kong Dollar', 'HKD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Hungarian Forint', 'HUF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Iceland Krona', 'ISK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Indian Rupee', 'INR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Indonesian Rupiah', 'IDR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Irish Punt', 'IEP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Israeli Shekel', 'ILS', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Italian Lira', 'ITL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Jamaican Dollar', 'JMD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Japanese Yen', 'JPY', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Jordanian Dinar', 'JOD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Kenyan Shilling', 'KES', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Kuwaiti Dinar', 'KWD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Laos Kip', 'LAK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Latvian Lats', 'LVL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Lebanese Pound', 'LBP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Lesotho Loti', 'LSL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Lithuanian Litas', 'LTL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Malagasy Franc', 'MGF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Malawi Kwacha', 'MWK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Malaysian Ringgit', 'MYR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Maldives Rufiyan', 'MVR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Maltese Pound', 'MTL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Mauritania Ouguiya', 'MRO', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Mauritius Rupee', 'MUR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Mexican Peso', 'MXN', '0', '1');	
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Mongolian Tugrik', 'MNT', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Moroccan Dirham', 'MAD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Mozambique Metical', 'MZM', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Myanmar Kyat', 'MMK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Namibian Dollar', 'NAD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Nepal Rupee', 'NPR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Netherlands Antilles Guilder', 'ANG', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('New Zealand Dollar', 'NZD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Nicaraguan Cordoba', 'NIO', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Nigerian Naira', 'NGN', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Norwegian Krone', 'NOK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Oman Rial', 'OMR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Pakistani Rupee', 'PKR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Papua New Guinea Kina', 'PGK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Peruvian Sol', 'PEN', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Philippines Peso', 'PHP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Polish Zloty', 'PLN', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Portuguese Escudo', 'PTE', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Qatari Rial', 'QAR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Renmimbi Yuan', 'CNY', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Romanian Leu', 'ROL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Russian Ruble', 'RUB', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Salomon Islands Dollar', 'SBD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Sao Tome & Principe Dobra', 'STD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Saudi Arabian Riyal', 'SAR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Seychelles Rupee', 'SCR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Sierra Leone Leone', 'SLL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Singapore Dollar', 'SGD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Slovak Koruna', 'SKK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Slovenian Tolar', 'SIT', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('South African Rand', 'ZAR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('South Korean Won', 'KRW', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Spanish Peseta', 'ESP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Sri Lanka Rupee', 'LKR', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('St. Helena Pound', 'SHP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Sudanese Dinar', 'SDD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Surinam Guilder', 'SRG', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Swaziland Lilangeni', 'SZL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Swedish Krona', 'SEK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Swiss Franc', 'CHF', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Syria Pound', 'SYP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Taiwan New Dollar', 'TWD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Tanzanian Shilling', 'TZS', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Thai Baht', 'THB', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Tonga Isl Paanga', 'TOP', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Trinidad Dollar', 'TTD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Tunisian Dinar', 'TND', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Turkish Lira', 'TRL', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Ugandan Shilling', 'UGX', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Ukraine Hryvnia', 'UAH', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('United Arab Emirates Dirham', 'AED', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('US Dollar', 'USD', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Vanuatu Vatu', 'VUV', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Venezuelan Bolivar', 'VEB', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Vietnam Dong', 'VND', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Western Samoa Tala', 'WST', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Zambia Kwacha', 'ZMK', '0', '1');
INSERT INTO currencies (full_name, name, active, exchange_rate) VALUES ('Zimbabwean Dollar', 'ZWD', '0', '1');

ALTER TABLE currencies ADD COLUMN curr_update int(11) default 1;
ALTER TABLE currencies ADD COLUMN curr_edit int(11) default 1;

#DELETE FROM conflines WHERE name = 'AMI_Host';
#DELETE FROM conflines WHERE name = 'AMI_Username';
#DELETE FROM conflines WHERE name = 'AMI_Secret';

ALTER TABLE servers ADD COLUMN ami_port varchar(255) default '5038';
ALTER TABLE servers ADD COLUMN ami_secret varchar(255) default 'morsecret';
ALTER TABLE servers ADD COLUMN ami_username varchar(255) default 'mor';

ALTER TABLE services ADD COLUMN owner_id int(11) default 0;

ALTER TABLE servers ADD COLUMN server_id int(11) DEFAULT 1;

ALTER TABLE calls ADD COLUMN did_inc_price double default 0;
ALTER TABLE calls ADD COLUMN did_prov_price double default 0;
ALTER TABLE calls ADD COLUMN localized_dst varchar(50) default NULL;


CREATE TABLE `hangupcausecodes` (
  `id` int(11) NOT NULL auto_increment,
  `code` int(11) NOT NULL,
  `description` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
)  ENGINE=InnoDB DEFAULT CHARSET=utf8; 



INSERT INTO hangupcausecodes (code, description) VALUES ('0', '0 - Unknow error'); 
INSERT INTO hangupcausecodes (code, description) VALUES ('1', '1 - Unallocated (unassigned) number.');
INSERT INTO hangupcausecodes (code, description) VALUES ('2', '2 - No route to specified transit network (national use).');
INSERT INTO hangupcausecodes (code, description) VALUES ('3', '3 - No route to destination.');
INSERT INTO hangupcausecodes (code, description) VALUES ('4', '4 - send special information tone.');
INSERT INTO hangupcausecodes (code, description) VALUES ('5', '5 - misdialed trunk prefix (national use).');
INSERT INTO hangupcausecodes (code, description) VALUES ('6', '6 - channel unacceptable.');  
INSERT INTO hangupcausecodes (code, description) VALUES ('7', '7 - call awarded. being delivered in an established channel.');
INSERT INTO hangupcausecodes (code, description) VALUES ('8', '8 - preemption.');
INSERT INTO hangupcausecodes (code, description) VALUES ('9', '9 - preemption - circuit reserved for reuse.');
INSERT INTO hangupcausecodes (code, description) VALUES ('16', '16 - normal call clearing.');
INSERT INTO hangupcausecodes (code, description) VALUES ('17', '17 - user busy.');
INSERT INTO hangupcausecodes (code, description) VALUES ('18', '18 - no user responding.');
INSERT INTO hangupcausecodes (code, description) VALUES ('19', '19 - no answer from user (user alerted).');
INSERT INTO hangupcausecodes (code, description) VALUES ('20', '20 - subscriber absent.');
INSERT INTO hangupcausecodes (code, description) VALUES ('21', '21 - call rejected.');
INSERT INTO hangupcausecodes (code, description) VALUES ('22', '22 - number changed.');
INSERT INTO hangupcausecodes (code, description) VALUES ('26', '26 - non-selected user clearing.');
INSERT INTO hangupcausecodes (code, description) VALUES ('27', '27 - destination out of order.');
INSERT INTO hangupcausecodes (code, description) VALUES ('28', '28 - invalid number format (address incomplete).');
INSERT INTO hangupcausecodes (code, description) VALUES ('29', '29 - facilities rejected.');
INSERT INTO hangupcausecodes (code, description) VALUES ('30', '30 - response to STATUS INQUIRY.');
INSERT INTO hangupcausecodes (code, description) VALUES ('31', '31 - normal. unspecified.');
INSERT INTO hangupcausecodes (code, description) VALUES ('34', '34 - no circuit/channel available.');
INSERT INTO hangupcausecodes (code, description) VALUES ('35', '35 - Call Queued.');
INSERT INTO hangupcausecodes (code, description) VALUES ('38', '38 - network out of order.');
INSERT INTO hangupcausecodes (code, description) VALUES ('39', '39 - permanent frame mode connection out-of-service.');
INSERT INTO hangupcausecodes (code, description) VALUES ('40', '40 - permanent frame mode connection operational.');
INSERT INTO hangupcausecodes (code, description) VALUES ('41', '41 - temporary failure.');
INSERT INTO hangupcausecodes (code, description) VALUES ('42', '42 - switching equipment congestion.');
INSERT INTO hangupcausecodes (code, description) VALUES ('43', '43 - access information discarded.');
INSERT INTO hangupcausecodes (code, description) VALUES ('44', '44 - requested circuit/channel not available.');
INSERT INTO hangupcausecodes (code, description) VALUES ('46', '46 - precedence call blocked.');
INSERT INTO hangupcausecodes (code, description) VALUES ('47', '47 - resource unavailable, unspecified.');
INSERT INTO hangupcausecodes (code, description) VALUES ('49', '49 - Quality of Service not available.');
INSERT INTO hangupcausecodes (code, description) VALUES ('50', '50 - requested facility not subscribed.');
INSERT INTO hangupcausecodes (code, description) VALUES ('52', '52 - outgoing calls barred');
INSERT INTO hangupcausecodes (code, description) VALUES ('53', '53 - outgoing calls barred within CUG.');
INSERT INTO hangupcausecodes (code, description) VALUES ('54', '54 - incoming calls barred');
INSERT INTO hangupcausecodes (code, description) VALUES ('55', '55 - incoming calls barred within CUG.');
INSERT INTO hangupcausecodes (code, description) VALUES ('57', '57 - bearer capability not authorized.');
INSERT INTO hangupcausecodes (code, description) VALUES ('58', '58 - bearer capability not presently available.');
INSERT INTO hangupcausecodes (code, description) VALUES ('62', '62 - inconsistency in outgoing information element.');
INSERT INTO hangupcausecodes (code, description) VALUES ('63', '63 - service or option not available. unspecified.');
INSERT INTO hangupcausecodes (code, description) VALUES ('65', '65 - bearer capability not implemented.');
INSERT INTO hangupcausecodes (code, description) VALUES ('66', '66 - channel type not implemented.');
INSERT INTO hangupcausecodes (code, description) VALUES ('69', '69 - requested facility not implemented.');
INSERT INTO hangupcausecodes (code, description) VALUES ('70', '70 - only restricted digital information bearer capability is available.');
INSERT INTO hangupcausecodes (code, description) VALUES ('79', '79 - service or option not implemented unspecified.');
INSERT INTO hangupcausecodes (code, description) VALUES ('81', '81 - invalid call reference value.');
INSERT INTO hangupcausecodes (code, description) VALUES ('82', '82 - identified channel does not exist.');
INSERT INTO hangupcausecodes (code, description) VALUES ('83', '83 - a suspended call exists, but this call identify does not.');
INSERT INTO hangupcausecodes (code, description) VALUES ('84', '84 - call identity in use.');
INSERT INTO hangupcausecodes (code, description) VALUES ('85', '85 - no call suspended.');
INSERT INTO hangupcausecodes (code, description) VALUES ('86', '86 - call having the requested call identity has been cleared.');
INSERT INTO hangupcausecodes (code, description) VALUES ('87', '87 - user not a member of CUG.');
INSERT INTO hangupcausecodes (code, description) VALUES ('88', '88 - incompatible destination.');
INSERT INTO hangupcausecodes (code, description) VALUES ('90', '90 - non-existent CUG.');
INSERT INTO hangupcausecodes (code, description) VALUES ('91', '91 - invalid transit network selection (national use).');
INSERT INTO hangupcausecodes (code, description) VALUES ('95', '95 - invalid message, unspecified.');
INSERT INTO hangupcausecodes (code, description) VALUES ('96', '96 - mandatory information element is missing.');
INSERT INTO hangupcausecodes (code, description) VALUES ('97', '97 - message type non-existent or not implemented.');
INSERT INTO hangupcausecodes (code, description) VALUES ('98', '98 - message not compatible with call state or message type non-existent.');
INSERT INTO hangupcausecodes (code, description) VALUES ('99', '99 - Information element / parameter non-existent or not implemented.');
INSERT INTO hangupcausecodes (code, description) VALUES ('100', '100 - Invalid information element contents.');
INSERT INTO hangupcausecodes (code, description) VALUES ('101', '101 - message not compatible with call state.');
INSERT INTO hangupcausecodes (code, description) VALUES ('102', '102 - recovery on timer expiry.');
INSERT INTO hangupcausecodes (code, description) VALUES ('103', '103 - parameter non-existent or not implemented - passed on (national use).');
INSERT INTO hangupcausecodes (code, description) VALUES ('110', '110 - message with unrecognized parameter discarded.');
INSERT INTO hangupcausecodes (code, description) VALUES ('111', '111 - protocol error, unspecified.');
INSERT INTO hangupcausecodes (code, description) VALUES ('127', '127 - Intel-working, unspecified.');
INSERT INTO hangupcausecodes (code, description) VALUES ('200', '200 - MOR can\'t determine who is calling');
INSERT INTO hangupcausecodes (code, description) VALUES ('201', '201 - User is blocked');
INSERT INTO hangupcausecodes (code, description) VALUES ('202', '202 - Reseller is blocked');
INSERT INTO hangupcausecodes (code, description) VALUES ('203', '203 - No rates for user');
INSERT INTO hangupcausecodes (code, description) VALUES ('204', '204 - No suitable providers found');
INSERT INTO hangupcausecodes (code, description) VALUES ('205', '205 - MOR PRO not authorized to work on this computer');
INSERT INTO hangupcausecodes (code, description) VALUES ('206', '206 - server_id is not set in mor.conf file');
INSERT INTO hangupcausecodes (code, description) VALUES ('207', '207 - Not clear who should receive call');
INSERT INTO hangupcausecodes (code, description) VALUES ('210', '210 - Balance > 0, but not enough to make call 1s in length');
INSERT INTO hangupcausecodes (code, description) VALUES ('211', '211 - Low balance for user');
INSERT INTO hangupcausecodes (code, description) VALUES ('212', '212 - Too low balance for more simultaneous calls');
INSERT INTO hangupcausecodes (code, description) VALUES ('213', '213 - Low balance for DID owner');
INSERT INTO hangupcausecodes (code, description) VALUES ('214', '214 - Too low balance for DID owner for more simultaneous calls');
INSERT INTO hangupcausecodes (code, description) VALUES ('215', '215 - Low balance for reseller');
INSERT INTO hangupcausecodes (code, description) VALUES ('216', '216 - Too low balance for reseller for more simultaneous calls');
INSERT INTO hangupcausecodes (code, description) VALUES ('217', '217 - Callback not initiated because device not found by ANI');



CREATE TABLE `serverproviders` (
  `id` int(11) NOT NULL auto_increment,
  `server_id` int(11) NOT NULL,
  `provider_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`)
)  ENGINE=InnoDB DEFAULT CHARSET=utf8;


ALTER TABLE dids ADD COLUMN comment varchar(255) default NULL;

CREATE TABLE `servers` (
  `id` int(11) NOT NULL auto_increment,
  `server_ip` varchar(255) NOT NULL,
  `stats_url` varchar(255) default NULL,
  `server_type` varchar(255) default NULL,
  `active` tinyint(4) default 0,
  `comment` varchar(255) default NULL, 
  `hostname` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
)  ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE servers ADD COLUMN maxcalllimit int(11) default 1000;

DELETE FROM sessions;

ALTER TABLE users ADD COLUMN send_invoice_types int(11) default 1;

INSERT INTO pbxfunctions (name, pf_type, context, extension, priority) VALUES ('Milliwatt',  'milliwatt', 'mor_pbxfunctions', 'milliwatt', 1);


#========================== MOR PRO 0.6 =======================

INSERT INTO conflines (name, value) VALUES ('CSV_Decimal', '.');

ALTER TABLE lcrproviders ADD COLUMN priority int(11) default 1;

ALTER TABLE activecalls ADD COLUMN provider_id int(11) default NULL;
ALTER TABLE users ADD COLUMN uniquehash varchar(10) default NULL;
ALTER TABLE payments ADD COLUMN owner_id int(11) default 0;

ALTER TABLE conflines DROP  KEY  `uname`;
ALTER TABLE conflines ADD COLUMN owner_id int(11) default 0;

ALTER TABLE locationrules ADD COLUMN lr_type enum('dst','src') default 'dst';
ALTER TABLE providerrules ADD COLUMN pr_type enum('dst','src') default 'dst';
ALTER TABLE payments ADD COLUMN card tinyint(4) default 0;

DROP TABLE IF EXISTS `shortnumbers`;
ALTER TABLE pbxfunctions ADD COLUMN pf_type varchar(20);
INSERT INTO pbxfunctions (id, name, pf_type, context, extension, priority) VALUES (1, 'Tell balance',  'tell_balance', 'mor_pbxfunctions', 1, 1);
INSERT INTO dialplans (name, dptype, data1, data2, data3, data4) VALUES ('Tell Balance', 'pbxfunction', '1', '1', 'USD', 'en');

UPDATE pbxfunctions SET extension = 'tell_balance' WHERE pf_type = 'tell_balance';

INSERT INTO conflines (name, value) VALUES ('AD_Sounds_Folder', '/home/mor/public/ad_sounds');

ALTER TABLE devices ADD COLUMN promiscredir enum('yes','no') default 'no';

#MOR PRO 0.6.pre4
#MOR PRO 0.6.pre5

#Auto-Dialer

CREATE TABLE `adactions` (
  `id` int(11) NOT NULL auto_increment,
  `priority` int(11) default NULL,
  `action` varchar(255) default NULL,
  `data` varchar(255) default NULL,
  `campaign_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `adnumbers` (
  `id` int(11) NOT NULL auto_increment,
  `number` varchar(255) default NULL,
  `status` varchar(255) default 'new',
  `campaign_id` int(11) default NULL,
  `executed_time` datetime default NULL,
  `completed_time` datetime default NULL,
  `channel` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `campaigns` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `campaign_type` varchar(255) default 'basic',
  `status` varchar(255) default NULL,
  `start_time` time default NULL,
  `stop_time` time default NULL,
  `max_retries` int(11) default '0',
  `retry_time` int(11) default '120',
  `wait_time` int(11) default '30',
  `user_id` int(11) default NULL,
  `device_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

#Click2Call Addon


CREATE TABLE `c2c_campaigns` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `description` varchar(255) default NULL,
  `user_id` int(11) default NULL,
  `device_id` int(11) default NULL,
  `first_dial` enum('company','client') NOT NULL default 'client',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE `c2c_commfields` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `description` varchar(255) default NULL,
  `c2c_campaign_id` int(11) NOT NULL,
  `commenttype` enum('checkbox','textarea','text') default 'text',
  `commentorder` int(11) NOT NULL default '99',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE users ADD COLUMN c2c_service_active tinyint(4) DEFAULT 0;


CREATE TABLE `c2c_calls` (
  `id` int(11) NOT NULL auto_increment,
  `c2c_campaign_id` int(11) NOT NULL,
  `client_number` varchar(255) default NULL,
  `client_call_id` int(11) default NULL,
  `company_call_id` int(11) default NULL,
  `calldate` datetime default NULL,
  `processed` tinyint(4) default 0,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE `c2c_comments` (
  `id` int(11) NOT NULL auto_increment,
  `c2c_commfield_id` int(11) default NULL,
  `c2c_call_id` int(11) default NULL,
  `value` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



ALTER TABLE devices MODIFY device_type varchar(20);
INSERT INTO devicetypes (name, ast_name) VALUES ('Virtual', 'Virtual');

INSERT INTO conflines (name, value) VALUES ('Temp_Dir', '/tmp/');
INSERT INTO conflines (name, value) VALUES ('Greetings_Folder', '/home/mor/public/c2c_greetings');

#MOR PRO 0.6.pre1

INSERT INTO conflines (name, value) VALUES ('Device_Range_MIN', '1001');
INSERT INTO conflines (name, value) VALUES ('Device_Range_MAX', '9999');


ALTER TABLE devices ADD COLUMN timeout int(11) DEFAULT 60;

ALTER TABLE devices ADD COLUMN process_sipchaninfo tinyint(4) DEFAULT 0;

ALTER TABLE calls ADD COLUMN peerip varchar(255) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN recvip varchar(255) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN sipfrom varchar(255) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN uri varchar(255) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN useragent varchar(255) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN peername varchar(255) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN t38passthrough tinyint(4) DEFAULT NULL;


ALTER TABLE providers ADD COLUMN timeout int(11) DEFAULT 60;



INSERT INTO conflines (name, value) VALUES ("WebMoney_Enabled", "1");
INSERT INTO conflines (name, value) VALUES ("WebMoney_Default_Currency", "USD");
INSERT INTO conflines (name, value) VALUES ("WebMoney_Min_Amount", "5");
INSERT INTO conflines (name, value) VALUES ("WebMoney_Default_Amount", "10");
INSERT INTO conflines (name, value) VALUES ("WebMoney_Test", "1");
INSERT INTO conflines (name, value) VALUES ("WebMoney_Purse", "Z616776332783");
INSERT INTO conflines (name, value) VALUES ("WebMoney_SIM_MODE", "0");
ALTER TABLE payments ADD COLUMN hash varchar(32);
ALTER TABLE payments ADD COLUMN bill_nr varchar(255);



# VM settings

INSERT INTO conflines (name, value) VALUES ('VM_Server_Active', '0');
INSERT INTO conflines (name, value) VALUES ('VM_Server_Device_ID', '');
INSERT INTO conflines (name, value) VALUES ('VM_Server_Retrieve_Extension', '*97');
INSERT INTO conflines (name, value) VALUES ('VM_Retrieve_Extension', '*97');



#MOR PRO 0.5.0.28
#MOR PRO 0.5.0.29
#MOR PRO 0.5.0.31
#MOR PRO 0.5 LiveCD


INSERT INTO dialplans (name, dptype) VALUES ('Quick Forward DIDs DP', 'quickforwarddids');

CREATE TABLE `quickforwarddids` (
  `id` int(11) NOT NULL auto_increment,
  `did_id` int(11) default NULL,
  `user_id` int(11) default NULL,
  `number` varchar(255) default NULL,
  `description` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO translations (name, native_name, short_name, position, flag) VALUES ('Urdu','','ur','108','pak');

#MOR PRO  0.5.0.25

#what CallerID to set on Web Callback
INSERT INTO conflines (name, value) VALUES ('WEB_Callback_CID', '');


INSERT INTO codecs (name, long_name, codec_type) VALUES ('h264', 'H.264 Video', 'video');
INSERT INTO conflines (name, value) VALUES ('Active_Calls_Refresh_Interval', '3');


CREATE TABLE `activecalls` (
  `id` bigint(11) NOT NULL auto_increment,
  `server_id` int(11) default NULL,
  `uniqueid` varchar(255) default NULL,
  `start_time` datetime default NULL,
  `answer_time` datetime default NULL,
  `transfer_time` datetime default NULL,
  `src` varchar(255) default NULL,
  `dst` varchar(255) default NULL,
  `src_device_id` int(11) default NULL,
  `dst_device_id` int(11) default NULL,
  `channel` varchar(255) default NULL,
  `dstchannel` varchar(255) default NULL,
  `prefix` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


ALTER TABLE calls ADD COLUMN server_id int(11) DEFAULT 1;


ALTER TABLE calls ADD COLUMN hangupcause int(11) DEFAULT NULL;


ALTER TABLE tariffs ADD COLUMN owner_id int(11) DEFAULT 0;
ALTER TABLE users ADD COLUMN owner_id int(11) DEFAULT 0;


CREATE TABLE `shortnumbers` (
  `id` int(11) NOT NULL auto_increment,
  `extension` varchar(255) default NULL,
  `pbxfunction_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `pbxfunctions` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `context` varchar(255) default NULL,
  `extension` varchar(255) default NULL,
  `priority` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


ALTER TABLE users ADD COLUMN hidden tinyint(4) DEFAULT 0;

INSERT INTO translations (name, native_name, short_name, position, flag) VALUES ('Chinese','','zn','107','chn');

ALTER TABLE invoicedetails ADD COLUMN invdet_type tinyint(4) DEFAULT 1;
UPDATE invoicedetails SET invdet_type = 0 WHERE name LIKE 'Calls%';

INSERT INTO conflines (name, value) VALUES ('CSV_Separator', ',');


INSERT INTO translations (name, native_name, short_name, position, flag) VALUES ('Belarussian','','by','103','blr');


ALTER TABLE devices ADD COLUMN cid_from_dids tinyint(4) DEFAULT 0;


ALTER TABLE emails ADD COLUMN template tinyint(4) DEFAULT 0;
UPDATE emails SET template = 1 WHERE name LIKE 'registration%';


ALTER TABLE users ADD COLUMN allow_loss_calls int(11) DEFAULT 0;

INSERT INTO translations (name, native_name, short_name, position, flag) VALUES ('Australian English','','au','102','aus');


INSERT INTO conflines (name, value) VALUES ('Reg_allow_user_enter_vat', '0');


INSERT INTO `emails` (`id`, `name`, `subject`, `date_created`, `body`) VALUES 
(1, 'registration_confirmation_for_user', 'Thank you for registering!', '2007-10-29 16:55:22', 0x596f7572206465766963652073657474696e67733a200d0a0d0a5365727665722049503a203c253d207365727665725f697020253e0d0a44657669636520747970653a203c253d206465766963655f7479706520253e0d0a557365726e616d653a203c253d206465766963655f757365726e616d6520253e0d0a50617373776f72643a203c253d206465766963655f70617373776f726420253e0d0a0d0a2d2d2d2d0d0a0d0a53657474696e677320746f206c6f67696e20746f204d4f5220696e746572666163653a0d0a0d0a4c6f67696e2055524c3a203c253d206c6f67696e5f75726c20253e0d0a557365726e616d653a203c253d206c6f67696e5f757365726e616d6520253e0d0a50617373776f72643a203c253d206c6f67696e5f70617373776f726420253e0d0a0d0a5468616e6b20796f7520666f72207265676973746572696e6721),
(2, 'registration_confirmation_for_admin', 'New user registered', '2007-10-29 16:55:51', 0x557365722073657474696e67733a200d0a0d0a557365723a0d0a4669727374204e616d652f436f6d70616e793a203c253d2066697273745f6e616d6520253e0d0a4c617374204e616d653a203c253d206c6173745f6e616d6520253e0d0a0d0a4465766963652073657474696e67730d0a0d0a44657669636520747970653a203c253d206465766963655f7479706520253e0d0a557365726e616d653a203c253d206465766963655f757365726e616d6520253e0d0a50617373776f72643a203c253d206465766963655f70617373776f726420253e0d0a0d0a53657474696e677320746f206c6f67696e20746f204d4f5220696e746572666163650d0a0d0a557365726e616d653a203c253d206c6f67696e5f757365726e616d6520253e0d0a50617373776f72643a203c253d206c6f67696e5f70617373776f726420253e);


CREATE TABLE `translations` (              
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,      
  `native_name` varchar(255) NOT NULL,   
  `short_name` varchar(255) NOT NULL,   
  `position` int(11) NOT NULL,
  `active` tinyint(4) default '1',
  `flag` varchar(255) NOT NULL,   
  PRIMARY KEY  (`id`)                
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `translations` VALUES ('1', 'English', '', 'en', '0', '1', 'gbr');
INSERT INTO `translations` VALUES ('2', 'Lithuanian', 'LietuviÅ³', 'lt', '1', '1', 'ltu');
INSERT INTO `translations` VALUES ('3', 'Spanish', 'EspaÃ±ol', 'es', '8', '1', 'esp');
INSERT INTO `translations` VALUES ('4', 'Dutch', 'Nederlands', 'nl', '15', '1', 'nld');
INSERT INTO `translations` VALUES ('5', 'Italian', 'Italiano', 'it', '4', '1', 'ita');
INSERT INTO `translations` VALUES ('6', 'Albanian', 'Gjuha shqipe', 'al', '7', '1', 'alb');
INSERT INTO `translations` VALUES ('7', 'Russian', 'Ð ÑƒÑÑÐºÐ¸Ð¹', 'ru', '9', '1', 'rus');
INSERT INTO `translations` VALUES ('8', 'Brazilian Portuguese', 'PortuguÃªs', 'pt', '2', '1', 'bra');
INSERT INTO `translations` VALUES ('9', 'Estonian', 'Eesti', 'et', '16', '1', 'est');
INSERT INTO `translations` VALUES ('10', 'Bulgarian', 'Ð‘ÑŠÐ»Ð³Ð°Ñ€ÑÐºÐ¸', 'bg', '18', '1', 'bgr');
INSERT INTO `translations` VALUES ('11', 'Swedish', 'Svenska', 'se', '11', '1', 'swe');
INSERT INTO `translations` VALUES ('12', 'German', 'Deutch', 'de', '6', '1', 'deu');
INSERT INTO `translations` VALUES ('13', 'Armenian', 'Õ°Õ¡ÕµÕ¥Ö€Õ¥Õ¶ Õ¬Õ¥Õ¦Õ¸Ö‚', 'am', '14', '1', 'arm');
INSERT INTO `translations` VALUES ('14', 'French', 'FranÃ§ais', 'fr', '10', '1', 'fra');
INSERT INTO `translations` VALUES ('15', 'Polish', 'Polski', 'pl', '3', '1', 'pol');
INSERT INTO `translations` VALUES ('16', 'Romanian', 'RomÃ¢nÄƒ', 'ro', '12', '1', 'rom');
INSERT INTO `translations` VALUES ('17', 'Turkish', 'TÃ¼rkÃ§e', 'tr', '5', '1', 'tur');
INSERT INTO `translations` VALUES ('18', 'Indonesian', 'Bahasa Indonesia', 'id', '13', '1', 'idn');
INSERT INTO `translations` VALUES ('19', 'Hungarian', 'Magyar', 'hu', '17', '1', 'hun');

INSERT INTO translations (name, native_name, short_name, position, flag) VALUES ('Slovenian','Slovene','sl','100','svn');
INSERT INTO translations (name, native_name, short_name, position, flag) VALUES ('Greek','EÎ»Î»Î·Î½Î¹ÎºÎ¬','gr','101','grc');
INSERT INTO translations (name, native_name, short_name, position, flag) VALUES ('Serbian','Srpski','sr','102','scg');


INSERT INTO conflines (name, value) VALUES ('Company', 'KolmiSoft');
INSERT INTO conflines (name, value) VALUES ('Logo_Picture', 'logo/mor_logo.png');
INSERT INTO conflines (name, value) VALUES ('Company_Email', 'mkezys@gmail.com');

INSERT INTO conflines (name, value) VALUES ('Days_for_did_close', '90');

INSERT INTO conflines (name, value) VALUES ('Version', 'MOR 0.5 PRO');
INSERT INTO conflines (name, value) VALUES ('Copyright_Title', ' by<a href=\'http://www.kolmisoft.com\' target=\"_blank\">KolmiSoft </a> 2006-2007');

INSERT INTO conflines (name, value) VALUES ('Invoice_Address1', 'Street Address');
INSERT INTO conflines (name, value) VALUES ('Invoice_Address2', 'City, Country');
INSERT INTO conflines (name, value) VALUES ('Invoice_Address3', 'Phone, fax');
INSERT INTO conflines (name, value) VALUES ('Invoice_Address4', 'Web, email');
INSERT INTO conflines (name, value) VALUES ('Invoice_Number_Start', 'INV');
INSERT INTO conflines (name, value) VALUES ('Invoice_Number_Length', '9');
INSERT INTO conflines (name, value) VALUES ('Invoice_Number_Type', '2');
INSERT INTO conflines (name, value) VALUES ('Invoice_Period_Start_Day', '01');
INSERT INTO conflines (name, value) VALUES ('Invoice_Show_Calls_In_Detailed', '1');
INSERT INTO conflines (name, value) VALUES ('Invoice_Bank_Details_Line1', 'Please make payments to:');
INSERT INTO conflines (name, value) VALUES ('Invoice_Bank_Details_Line2', 'Company name');
INSERT INTO conflines (name, value) VALUES ('Invoice_Bank_Details_Line3', 'Bank name');
INSERT INTO conflines (name, value) VALUES ('Invoice_Bank_Details_Line4', 'Bank account number');
INSERT INTO conflines (name, value) VALUES ('Invoice_Bank_Details_Line5', 'Add. info');
INSERT INTO conflines (name, value) VALUES ('Invoice_End_Title', 'Thank you for your bussiness!');
INSERT INTO conflines (name, value) VALUES ('Invoice_Address_Format', '2');

INSERT INTO conflines (name, value) VALUES ('C2C_Active', '1');

INSERT INTO conflines (name, value) VALUES ('CB_Active', '1');
INSERT INTO conflines (name, value) VALUES ('CB_Temp_Dir', '/tmp');
INSERT INTO conflines (name, value) VALUES ('CB_Spool_Dir', '/var/spool/asterisk/outgoing');
INSERT INTO conflines (name, value) VALUES ('CB_MaxRetries', '0');
INSERT INTO conflines (name, value) VALUES ('CB_RetryTime', '10');
INSERT INTO conflines (name, value) VALUES ('CB_WaitTime', '20');

INSERT INTO conflines (name, value) VALUES ('Registration_enabled', '1');
INSERT INTO conflines (name, value) VALUES ('Tariff_for_registered_users', '2');
INSERT INTO conflines (name, value) VALUES ('LCR_for_registered_users', '1');
INSERT INTO conflines (name, value) VALUES ('Default_VAT_Percent', '18');
INSERT INTO conflines (name, value) VALUES ('Default_Country_ID', '123');
INSERT INTO conflines (name, value) VALUES ('Asterisk_Server_IP', '111.222.333.444');
INSERT INTO conflines (name, value) VALUES ('Default_CID_Name', '');
INSERT INTO conflines (name, value) VALUES ('Default_CID_Number', '');

INSERT INTO conflines (name, value) VALUES ('Paypal_Enabled', '1');
INSERT INTO conflines (name, value) VALUES ('PayPal_Email', '');
INSERT INTO conflines (name, value) VALUES ('PayPal_Default_Amount', '10');
INSERT INTO conflines (name, value) VALUES ('PayPal_Min_Amount', '5');
INSERT INTO conflines (name, value) VALUES ('PayPal_Test', '0');

INSERT INTO conflines (name, value) VALUES ('Change_Zap', '0');
INSERT INTO conflines (name, value) VALUES ('Change_Zap_to', 'PSTN');

INSERT INTO conflines (name, value) VALUES ('Vouchers_Enabled', '1');
INSERT INTO conflines (name, value) VALUES ('Voucher_Number_Length', '15');
INSERT INTO conflines (name, value) VALUES ('Voucher_Disable_Time', '60');
INSERT INTO conflines (name, value) VALUES ('Voucher_Attempts_to_Enter', '3');

INSERT INTO conflines (name, value) VALUES ('Send_Email_To_User_After_Registration', '0');
INSERT INTO conflines (name, value) VALUES ('Send_Email_To_Admin_After_Registration', '0');

DROP TABLE IF EXISTS `emails`;
CREATE TABLE `emails` (              
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,      
  `subject` varchar(255) NOT NULL,   
  `date_created` datetime NOT NULL,  
  `body` blob NOT NULL,      
  PRIMARY KEY  (`id`)                
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

#Extlines _X.

DELETE FROM extlines WHERE exten = "_X.";
INSERT INTO `extlines` (context, exten, priority, app, appdata, device_id) VALUES ('mor', '_X.', '1', 'AGI', 'mor-recordings.php|${CALLERID(num)}|${EXTEN}', '0');
INSERT INTO `extlines` (context, exten, priority, app, appdata, device_id) VALUES ('mor', '_X.', '2', 'mor', '${EXTEN}', '0');
INSERT INTO `extlines` (context, exten, priority, app, appdata, device_id) VALUES ('mor', '_X.', '3', 'GotoIf', '$[$["${DIALSTATUS}" = "CHANUNAVAIL"] | $["${DIALSTATUS}" = "CONGESTION"]]?FAILED|1', '0');
INSERT INTO `extlines` (context, exten, priority, app, appdata, device_id) VALUES ('mor', '_X.', '4', 'GotoIf', '$["${DIALSTATUS}" = "BUSY"]?BUSY|1:HANGUP|1', '0');


DELETE FROM extlines WHERE exten = 'BUSY' or exten = 'HANGUP' or exten = 'FAILED';

#BUSY extlines
INSERT INTO `extlines` (context, exten, priority, app, appdata, device_id) VALUES ('mor', 'BUSY', '1', 'Busy', '10', '0');
INSERT INTO `extlines` (context, exten, priority, app, appdata, device_id) VALUES ('mor', 'BUSY', '2', 'Hangup', '', '0');

#HANGUP extlines
INSERT INTO `extlines`(context, exten, priority, app, appdata, device_id) VALUES ('mor', 'HANGUP', '1', 'Congestion', '4', '0');
INSERT INTO `extlines`(context, exten, priority, app, appdata, device_id) VALUES ('mor', 'HANGUP', '2', 'Hangup', '', '0');

#FAILED extlines
INSERT INTO `extlines` (context, exten, priority, app, appdata, device_id) VALUES ('mor', 'FAILED', '1', 'Congestion', '4', '0');
INSERT INTO `extlines` (context, exten, priority, app, appdata, device_id) VALUES ('mor', 'FAILED', '2', 'Hangup', '', '0');


#0.4.7

INSERT INTO conflines (name, value) VALUES ('Email_Fax_From_Sender', 'fax@some.domain.com');

# 0.4.6 (tar)

INSERT INTO conflines (name, value) VALUES ('Items_Per_Page', '50');

INSERT INTO conflines (name, value) VALUES ('Nice_Number_Digits', '2');
INSERT INTO conflines (name, value) VALUES ('User_Wholesale_Enabled', '1');

ALTER TABLE cards ADD COLUMN  `frozen_balance` double default 0;

ALTER TABLE dialplans ADD COLUMN  `data1` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data2` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data3` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data4` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data5` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data6` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data7` varchar(255) default NULL;
ALTER TABLE dialplans ADD COLUMN  `data8` varchar(255) default NULL;


#VoiceMailMain
INSERT INTO `extlines`(context, exten, priority, app, appdata, device_id)  VALUES ('mor', '*89', '1', 'VoiceMailMain', '', '0');
INSERT INTO `extlines` (context, exten, priority, app, appdata, device_id) VALUES ('mor', '*89', '2', 'Hangup', '', '0');

INSERT INTO `extlines`(context, exten, priority, app, appdata, device_id)  VALUES ('mor', 'fax', '1', 'Goto', 'mor_fax2email|123|1', '0');

ALTER TABLE subscriptions ADD COLUMN  `memo` varchar(255) default NULL;

INSERT INTO conflines (name, value) VALUES ('Email_Sending_Enabled', '1');
INSERT INTO conflines (name, value) VALUES ('Fax_Device_Enabled', '1');

CREATE TABLE `pdffaxes` (
  `id` int(11) NOT NULL auto_increment,
  `device_id` int(11) default NULL,
  `filename` varchar(255) default NULL,
  `receive_time` datetime default NULL,
  `size` int(11) default NULL,
  `deleted` tinyint(4) default '0',
  `uniqueid` varchar(255) default NULL,
  `fax_sender` varchar(255) default NULL,
  `status` varchar(255) default 'good',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `pdffaxemails` (
  `id` int(11) NOT NULL auto_increment,
  `device_id` int(11) default NULL,
  `email` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

#0.4.5 (tar)

ALTER TABLE devices ADD COLUMN  `pin` varchar(255) default NULL;
INSERT INTO conflines (name, value) VALUES ('Device_PIN_Length', '6');

INSERT INTO conflines (name, value) VALUES ('Admin_Browser_Title', 'Kolmisoft - MOR');

INSERT INTO conflines (name, value) VALUES ('Email_Batch_Size', '50');
INSERT INTO conflines (name, value) VALUES ('Email_Smtp_Server', 'smtp.gmail.com');
INSERT INTO conflines (name, value) VALUES ('Email_Domain', 'localhost.localdomain');
INSERT INTO conflines (name, value) VALUES ('Email_Login', '');
INSERT INTO conflines (name, value) VALUES ('Email_Password', '');

#0.4.4

CREATE TABLE `emails` (              
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,      
  `subject` varchar(255) NOT NULL,   
  `date_created` datetime NOT NULL,  
  `body` blob NOT NULL,      
  PRIMARY KEY  (`id`)                
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `sessions` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `session_id` varchar(255) default NULL,
  `data` longtext,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`),
  KEY `index_sessions_on_session_id` (`session_id`),
  KEY `index_sessions_on_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE actions ADD COLUMN  `data2` varchar(255) default NULL;

#config table
CREATE TABLE `conflines` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `value` varchar(255) default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `uname` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


INSERT INTO conflines (name, value) VALUES ('Agreement_Number_Length', '10');
INSERT INTO conflines (name, value) VALUES ('Paypal_Default_Currency', 'USD');


ALTER TABLE lcrproviders ADD COLUMN `active` tinyint(4) NOT NULL default '1';


#Montenegro
INSERT INTO directions (name, code) VALUES ('Montenegro', 'MBX');
INSERT INTO destinationgroups (name, desttype, flag) VALUES ('Montenegro', 'FIX', 'mbx');
INSERT INTO destinationgroups (name, desttype, flag) VALUES ('Montenegro', 'MOB', 'mbx');
INSERT INTO destinations (prefix, direction_code, subcode, name, destinationgroup_id) VALUES ('382', 'MBX', 'FIX', '', (SELECT id FROM destinationgroups WHERE name = 'Montenegro' AND desttype='FIX' ));
INSERT INTO destinations (prefix, direction_code, subcode, name, destinationgroup_id) VALUES ('3826', 'MBX', 'MOB', '', (SELECT id FROM destinationgroups WHERE name = 'Montenegro' AND desttype='MOB' ));


#0.4.3


CREATE INDEX rd USING BTREE ON ratedetails(rate_id, daytype, start_time, end_time);


CREATE TABLE `providerrules` (
  `id` int(11) NOT NULL auto_increment,
  `provider_id` int(11) NOT NULL,
  `name` varchar(255) default NULL,
  `enabled` tinyint(4) NOT NULL default '1',
  `cut` varchar(255) default NULL,
  `add` varchar(255) default NULL,
  `minlen` int(11) NOT NULL default '1',
  `maxlen` int(11) NOT NULL default '100',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `callflows` (
  `id` int(11) NOT NULL auto_increment,
  `device_id` int(11) default NULL,
  `cf_type` varchar(255) default NULL,
  `priority` int(11) NOT NULL default '1',
  `action` varchar(255) default NULL,
  `data` varchar(255) default NULL,
  `data2` varchar(255) default NULL,
  `time_data` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE didrates ADD COLUMN `rate_type` varchar(20) default 'provider';
ALTER TABLE dids ADD COLUMN `language` varchar(10) default 'en';

ALTER TABLE users ADD COLUMN `vouchers_disabled_till` datetime default '2000-01-01 00:00:00';

ALTER TABLE devices ADD COLUMN `tell_balance` tinyint(4) NOT NULL default '0';
ALTER TABLE devices ADD COLUMN `tell_time` tinyint(4) NOT NULL default '0';
ALTER TABLE devices ADD COLUMN `tell_rtime_when_left` int(11) NOT NULL default '60';
ALTER TABLE devices ADD COLUMN `repeat_rtime_every` int(11) NOT NULL default '60';

ALTER TABLE devices ADD COLUMN `t38pt_udptl` varchar(255) default 'no';

ALTER TABLE payments ADD COLUMN `vat_percent` double NOT NULL default '0';

CREATE TABLE `vouchers` (
  `id` int(11) NOT NULL auto_increment,
  `number` varchar(255) NOT NULL,
  `tag` varchar(255) NOT NULL,
  `credit_with_vat` double NOT NULL default '0',
  `vat_percent` double NOT NULL,
  `user_id` int(11) NOT NULL default '-1',
  `use_date` datetime default NULL,
  `active_till` datetime NOT NULL,
  `currency` varchar(255) NOT NULL,
  `payment_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


ALTER TABLE voicemail_boxes CHANGE id uniqueid INTEGER  NOT NULL auto_increment;

ALTER TABLE cardgroups ADD COLUMN `location_id` int(11) default '1';
ALTER TABLE devices ADD COLUMN `regserver` varchar(255);

#0.4.2

ALTER TABLE devices ADD COLUMN `ani` tinyint(4) default 0;
ALTER TABLE providers ADD COLUMN `ani` tinyint(4) default 0;

CREATE TABLE `callerids` (
  `id` int(11) NOT NULL auto_increment,
  `cli` varchar(255) default NULL,
  `device_id` int(11) default NULL,
  `description` varchar(255) default NULL,
  `added_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

# ---- e.164 numbers - without int.prefix -----
UPDATE destinations SET prefix = CONCAT("", SUBSTRING(prefix,3,LENGTH(prefix))) WHERE SUBSTRING(prefix,1,2) = "00";

INSERT INTO `locationrules` VALUES ('1', '1', 'Int. prefix', '1', '00', '', '10', '20'); 

CREATE TABLE `currencies` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `full_name` varchar(255) default NULL,
  `exchange_rate` double NOT NULL default '1',
  `active` tinyint(4) NOT NULL default '1',
  `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `currencies` VALUES ('1', 'USD', 'United States dollar', '1', '1', CURRENT_TIMESTAMP);
INSERT INTO `currencies` VALUES ('2', 'EUR', 'Euro', '0.73853104', '1', CURRENT_TIMESTAMP);

ALTER TABLE tariffs ADD COLUMN `currency` varchar(255);
UPDATE tariffs SET currency = (SELECT name FROM currencies WHERE id = 1);

UPDATE users SET vat_percent = 0 WHERE vat_percent IS NULL;

ALTER TABLE dids ADD COLUMN `provider_id` int(11) default 0;
UPDATE dids SET provider_id = 1;
ALTER TABLE calls ADD COLUMN `callertype` enum('Local','Outside') default 'Local';

#0.4.1.10 FREE

ALTER TABLE devices ADD COLUMN `istrunk` int(11) default 0;

ALTER TABLE devices ADD COLUMN `description` varchar(255);

ALTER TABLE aratedetails ADD COLUMN `daytype` enum('','FD','WD') default '';
ALTER TABLE aratedetails ADD COLUMN `start_time` time default '00:00:00';
ALTER TABLE aratedetails ADD COLUMN `end_time` time default '23:59:59';

ALTER TABLE acustratedetails ADD COLUMN `daytype` enum('','FD','WD') default '';
ALTER TABLE acustratedetails ADD COLUMN `start_time` time default '00:00:00';
ALTER TABLE acustratedetails ADD COLUMN `end_time` time default '23:59:59';

ALTER TABLE ratedetails ADD COLUMN `daytype` enum('','FD','WD') default '';

CREATE TABLE `days` (
  `id` int(11) NOT NULL auto_increment,
  `date` date default NULL,
  `daytype` enum('FD','WD') default 'FD' COMMENT 'Free Day or Work Day?',
  `description` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


#0.4

ALTER TABLE devices ADD COLUMN `location_id` int(11) default 1;

CREATE TABLE `invoicedetails` (
  `id` int(11) NOT NULL auto_increment,
  `invoice_id` int(11) default NULL,
  `name` varchar(255) default NULL,
  `quantity` int(11) default NULL,
  `price` double default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `invoices` (
  `id` int(11) NOT NULL auto_increment,
  `user_id` int(11) NOT NULL,
  `period_start` date NOT NULL COMMENT 'when start to bill',
  `period_end` date NOT NULL COMMENT 'till when bill',
  `issue_date` date NOT NULL COMMENT 'when invoice issued',
  `paid` tinyint(4) NOT NULL default '0',
  `paid_date` datetime default NULL,
  `price` double NOT NULL default '0',
  `price_with_vat` double NOT NULL default '0',
  `payment_id` int(11) default NULL,
  `number` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `customrates` (
  `id` int(11) NOT NULL auto_increment,
  `user_id` int(11) default NULL,
  `destinationgroup_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `acustratedetails` (
  `id` int(11) NOT NULL auto_increment,
  `from` int(11) default NULL,
  `duration` int(11) default NULL,
  `artype` enum('event','minute') default NULL,
  `round` int(11) default NULL,
  `price` double default NULL,
  `customrate_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `locations` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO locations VALUES (1,'Global');

CREATE TABLE `locationrules` (
  `id` int(11) NOT NULL auto_increment,
  `location_id` int(11) NOT NULL,
  `name` varchar(255) default NULL,
  `enabled` tinyint(4) NOT NULL default '1',
  `cut` varchar(255) default NULL,
  `add` varchar(255) default NULL,
  `minlen` int(11) NOT NULL default '1',
  `maxlen` int(11) NOT NULL default '100',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
 


#0.3.6

ALTER TABLE devices ADD COLUMN `dtmfmode` varchar(255) default 'rfc2833';
ALTER TABLE devices ADD COLUMN `callgroup` int(11) default NULL;
ALTER TABLE devices ADD COLUMN `pickupgroup` int(11) default NULL;
ALTER TABLE devices ADD COLUMN `fromuser` varchar(255) default NULL;
ALTER TABLE devices ADD COLUMN `fromdomain` varchar(255) default NULL;
ALTER TABLE devices ADD COLUMN `trustrpid` varchar(255) default 'no';
ALTER TABLE devices ADD COLUMN `sendrpid` varchar(255) default 'no';
ALTER TABLE devices ADD COLUMN `insecure` varchar(255) default 'no';
ALTER TABLE devices ADD COLUMN `progressinband` varchar(255) default 'never';
ALTER TABLE devices ADD COLUMN `videosupport` varchar(255) default 'no';

#empty destinations -> import new ones, same for directions

ALTER TABLE calls ADD COLUMN prefix varchar(50) DEFAULT NULL;

ALTER TABLE rates DROP INDEX td;

CREATE TABLE `aratedetails` (
`id` int(11) NOT NULL AUTO_INCREMENT,
`from` int(11) DEFAULT NULL,
`duration` int(11) DEFAULT NULL,
`artype` enum('event','minute') DEFAULT NULL,
`round` int(11) DEFAULT NULL,
`price` double DEFAULT NULL,
`rate_id` int(11) DEFAULT NULL, 
PRIMARY KEY (`id`)
) ENGINE=InnoDB;

ALTER TABLE rates ADD COLUMN destinationgroup_id int(11) DEFAULT NULL;

DROP TABLE IF EXISTS destgroups;

ALTER TABLE destinations ADD COLUMN destinationgroup_id int(11) DEFAULT 0;


#0.3.3

CREATE TABLE `payments` (
  `id` int(11) NOT NULL auto_increment,
  `paymenttype` varchar(255) default NULL,
  `amount` double NOT NULL default '0',
  `currency` varchar(5) NOT NULL default 'USD',
  `email` varchar(255) default NULL,
  `date_added` datetime default NULL,
  `completed` tinyint(4) NOT NULL default '0',
  `transaction_id` varchar(255) default NULL,
  `shipped_at` datetime default NULL,
  `fee` double default '0',
  `gross` double default '0',
  `first_name` varchar(255) default NULL,
  `last_name` varchar(255) default NULL,
  `payer_email` varchar(255) default NULL,
  `residence_country` varchar(255) default NULL,
  `payer_status` varchar(255) default NULL,
  `tax` double default '0',
  `user_id` int(11) default NULL,
  `pending_reason` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB;


CREATE TABLE `services` (
`id` int(11) NOT NULL AUTO_INCREMENT,
`name` varchar(255) DEFAULT NULL,
`servicetype` varchar(255) NOT NULL DEFAULT 'dialing',
`destinationgroup_id` int(11) DEFAULT NULL,
`periodtype` varchar(255) NOT NULL DEFAULT 'day',
`price` double NOT NULL DEFAULT '0',
PRIMARY KEY (`id`)
) ENGINE=InnoDB;

CREATE TABLE `subscriptions` (
`id` int(11) NOT NULL AUTO_INCREMENT,
`service_id` int(11) DEFAULT NULL,
`user_id` int(11) DEFAULT NULL,
`device_id` int(11) DEFAULT NULL,
`activation_start` datetime DEFAULT NULL,
`activation_end` datetime DEFAULT NULL,
`added` datetime DEFAULT NULL, 
PRIMARY KEY (`id`)
) ENGINE=InnoDB;

ALTER TABLE calls ADD COLUMN provider_id int(11) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN provider_rate double DEFAULT NULL;
ALTER TABLE calls ADD COLUMN provider_billsec int(11) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN provider_price double DEFAULT NULL;

ALTER TABLE calls ADD COLUMN user_id int(11) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN user_rate double DEFAULT NULL;
ALTER TABLE calls ADD COLUMN user_billsec int(11) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN user_price double DEFAULT NULL;

ALTER TABLE calls ADD COLUMN reseller_id int(11) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN reseller_rate double DEFAULT NULL;
ALTER TABLE calls ADD COLUMN reseller_billsec int(11) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN reseller_price double DEFAULT NULL;

ALTER TABLE calls ADD COLUMN partner_id int(11) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN partner_rate double DEFAULT NULL;
ALTER TABLE calls ADD COLUMN partner_billsec int(11) DEFAULT NULL;
ALTER TABLE calls ADD COLUMN partner_price double DEFAULT NULL;

UPDATE calls SET provider_rate = selfcost_rate, provider_billsec = prov_billsec, provider_price = prov_price, user_rate = rate, user_billsec = count_billsec, user_price = price;

ALTER TABLE calls DROP COLUMN selfcost_rate;
ALTER TABLE calls DROP COLUMN prov_billsec;
ALTER TABLE calls DROP COLUMN prov_price;
ALTER TABLE calls DROP COLUMN rate;
ALTER TABLE calls DROP COLUMN count_billsec;
ALTER TABLE calls DROP COLUMN price;

CREATE INDEX provider_id USING BTREE ON calls(provider_id);

ALTER TABLE users ADD COLUMN credit double DEFAULT -1;

CREATE TABLE IF NOT EXISTS `destinationgroups` (
`id` int(11) NOT NULL AUTO_INCREMENT,
`name` varchar(255) DEFAULT NULL,
`desttype` varchar(10) DEFAULT 'FIX',
`flag` varchar(10) DEFAULT NULL,
PRIMARY KEY (`id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `destgroups` (
`id` int(11) NOT NULL AUTO_INCREMENT,
`destinationgroup_id` int(11) DEFAULT NULL,
`destination_id` int(11) DEFAULT NULL,
PRIMARY KEY (`id`)
) ENGINE=InnoDB COMMENT='Connects destinations with their groups';


CREATE TABLE IF NOT EXISTS `devicegroups` (
`id` int(11) NOT NULL AUTO_INCREMENT,
`user_id` int(11) DEFAULT NULL,
`address_id` int(11) DEFAULT NULL,
`name` varchar(100) DEFAULT NULL,
`added` timestamp NULL DEFAULT CURRENT_TIMESTAMP, 
`primary` tinyint(4) NOT NULL DEFAULT '0', 
PRIMARY KEY (`id`)
) ENGINE=InnoDB;


ALTER TABLE devices ADD COLUMN devicegroup_id int(11) DEFAULT NULL;


CREATE TABLE IF NOT EXISTS `addresses` (
`id` int(11) NOT NULL AUTO_INCREMENT,
`direction_id` int(11) DEFAULT NULL,
`state` varchar(30) DEFAULT NULL,
`county` varchar(30) DEFAULT NULL,
`city` varchar(30) DEFAULT NULL,
`postcode` varchar(20) DEFAULT NULL COMMENT 'also zip',
`address` varchar(100) DEFAULT NULL,
`phone` varchar(30) DEFAULT NULL,
`mob_phone` varchar(30) DEFAULT NULL,
`fax` varchar(30) DEFAULT NULL,
`email` varchar(50) DEFAULT NULL,
PRIMARY KEY (`id`)
) ENGINE=InnoDB;


ALTER TABLE users ADD COLUMN clientid varchar(30) DEFAULT NULL COMMENT 'company or person ID';
ALTER TABLE users ADD COLUMN agreement_number varchar(20) DEFAULT NULL;
ALTER TABLE users ADD COLUMN agreement_date date DEFAULT NULL;
ALTER TABLE users ADD COLUMN language varchar(10) DEFAULT NULL;
ALTER TABLE users ADD COLUMN taxation_country int(11) DEFAULT NULL;
ALTER TABLE users ADD COLUMN vat_number varchar(30) DEFAULT NULL;
ALTER TABLE users ADD COLUMN vat_percent double DEFAULT NULL;
ALTER TABLE users ADD COLUMN address_id int(11) DEFAULT NULL;
ALTER TABLE users ADD COLUMN accounting_number varchar(30) DEFAULT NULL;


CREATE INDEX card_id USING BTREE ON calls(card_id);

# v0.3

ALTER TABLE devices ADD COLUMN canreinvite varchar(10) DEFAULT 'no';

ALTER TABLE groups ADD COLUMN  `grouptype` varchar(255) NOT NULL default 'simple';

ALTER TABLE calls ADD COLUMN dst_user_id INTEGER  NOT NULL DEFAULT -1 COMMENT 'users id for an incoming call';
UPDAT
ALTER TABLE calls ADD INDEX dst_user_iE IGNORE calls, devices SET dst_user_id = devices.user_id where calls.dst_device_id > 0 and devices.id = calls.dst_device_id;
UPDATE IGNORE calls, dids SET dst_user_id = dids.user_id where calls.did_id > 0 and dids.id = calls.did_id;

ALTER TABLE calls ADD INDEX dst_user_id_index(dst_user_id);