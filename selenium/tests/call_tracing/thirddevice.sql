INSERT INTO `devices` (`id`,`name`,`host`   ,`secret`      ,`context`  ,`ipaddr`,`port`,`regseconds`,`accountcode`,`callerid`,`extension`,`voicemail_active`,`username`,`device_type`,`user_id`,`primary_did_id`,`works_not_logged`,`forward_to`,`record`,`transfer`,`disallow`,`allow`    ,`deny`           ,`permit`         ,`nat`            ,`qualify`,`fullcontact`,`canreinvite`,`devicegroup_id`,`dtmfmode`,`callgroup`,`pickupgroup`,`fromuser`,`fromdomain`,`trustrpid`,`sendrpid`,`insecure`,`progressinband`,`videosupport`,`location_id`,`description`,`istrunk` ,`cid_from_dids`,`pin`   ,`tell_balance`,`tell_time`,`tell_rtime_when_left`,`repeat_rtime_every`,`t38pt_udptl`,`regserver`,`ani`,`promiscredir`,`timeout`,`process_sipchaninfo`,`temporary_id`,`allow_duplicate_calls`,`call_limit`,`lastms`,`faststart`,`h245tunneling`,`latency`,`grace_time`,`recording_to_email`,`recording_keep`,`recording_email`,`record_forced`,`fake_ring`,`save_call_log`,`mailbox`     ,`server_id`,`enable_mwi`,`authuser`,`requirecalltoken`,`language`)
VALUES                ( 112,1001  ,'dynamic','6mgs1bhnz4cy','mor_local',''      ,0     ,0           , 9           , NULL     ,10011324   ,0                 ,1001      ,'SIP'        ,5        ,0               ,1                 ,0           ,0       ,'no'      ,'all'     ,'alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'            ,1000     ,NULL         ,'no'         ,NULL            ,'rfc2833' ,NULL       ,NULL         ,''        ,''          ,'no'       ,'no'      ,''        ,'no'            ,'no'         ,1             ,'specdevice' ,0         ,0              , 864193 ,0             ,0          ,60                    ,60                  ,'no'         ,NULL       ,0    ,'no'          ,60       ,0                    ,NULL          ,0                      ,0           ,0       ,'yes'      ,'yes'          ,0        ,NULL        ,0                   ,0               ,''               ,0              ,0          ,0              ,'1001@default',1          ,0           ,''        ,'no'              ,'en');
update conflines set value = 1 WHERE ( name = 'Default_device_location_id' and owner_id =3);
update devices set location_id = 1 where user_id = 5;

