/*sito sql reikia tam, kad butu atliktas summary.case testas, nes good callsuose nera reseller provaiderio ir neiseina istesuoti terminatoriu, o various calls netinka, nes visiskai sugadintos kainos*/
UPDATE `calls` set provider_id=3 where id=30;
UPDATE `calls` set provider_id=3 where id=32;
UPDATE `calls` set provider_id=3 where id=34;
UPDATE `calls` set provider_id=3 where id=36;
UPDATE `calls` set provider_id=3 where id=37;
UPDATE `calls` set provider_id=3 where id=59;
UPDATE `calls` set provider_id=3 where id=70;

