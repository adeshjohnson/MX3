INSERT INTO conflines (name, value) SELECT 'unhide_default_currency_page', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines WHERE name = 'unhide_default_currency_page' and owner_id = 0);
