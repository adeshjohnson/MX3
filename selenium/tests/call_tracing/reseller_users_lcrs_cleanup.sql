#del testu optimizavimo ir pakeitimo, kad rspro nebegali tapti paprastu reseleriu, reikalinga sita eilute, kuri sutvarko reselerio useriu lcrus. 
#kol reseleris nera rspro, jis ir jo useriai naudoja admino lcr
#reikes sita dalyka sutvarkyti, kai duomenu kurimas bus keliamas i bundles
update users set lcr_id=1 where owner_id=3;
