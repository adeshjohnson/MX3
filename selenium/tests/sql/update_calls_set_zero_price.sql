update calls set user_price=0,did_prov_price=0,did_inc_price=0,partner_price=0,reseller_price=0,user_price=0,provider_price=0,did_price=0;
delete from calls where user_id=4 or src_device_id=9 or dst_device_id=9;
