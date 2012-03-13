update payments set currency='EUR' where date_added like '%00:00:01';
update payments set transaction_id='1234567899098765432' where completed=0;
