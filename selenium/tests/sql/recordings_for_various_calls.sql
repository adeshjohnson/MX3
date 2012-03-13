#recordings
INSERT INTO `recordings` (`id`, `datetime`         , `src`        , `dst`        , `src_device_id`, `dst_device_id`, `call_id`, `user_id`, `path`, `deleted`, `send_time`, `comment`, `size`, `uniqueid`    , `visible_to_user`, `dst_user_id`, `local`, `visible_to_dst_user`) VALUES
                         (11, '2011-11-01 07:00:01', '37060011221', '37060011224', 5              , 4              , 211      , 0        , ''    , 0        , NULL       , ''       , 1024  , '1232113373.3', 1                , 2            , 1      , 1),
                         (12, '2011-11-08 23:00:01', '37060011226', '37060011223', 4              , 5              , 224      , 2        , ''    , 0        , NULL       , ''       , 928797, '1232113373.3', 0                , 0            , 1      , 1),
                         (13, '2011-11-12 12:00:01', '37060011238', '123123'     , 9              , 0              , 236      , 4        , ''    , 0        , NULL       , ''       , 76346 , '1232113375.3', 1                , -1           , 1      , 1),
                         (14, '2011-11-13 17:00:01', '37060011233', '37060011221', 8              , 5              , 241      , 5        , ''    , 0        , NULL       , ''       , 578965, '1232113375.3', 1                , 0            , 1      , 0),
                         (15, '2011-11-14 23:00:01', '37060011225', '37060011221', 4              , 5              , 248      , 2        , ''    , 0        , NULL       , ''       , 98765 , '1232113377.3', 1                , 0            , 1      , 1),
                         (16, '2011-11-23 07:00:01', '37060011233', '37060011224', 8              , 4              , 273      , 5        , ''    , 0        , NULL       , ''       , 435464, '1232113377.3', 0                , 2            , 1      , 0);
update calls set real_duration=60 where id in (211,224,273);
update calls set real_billsec=50 where id in (211,224,273);
update calls set real_duration=30 where id in (236,241,248);
update calls set real_billsec=0 where id in (236,241,248);
