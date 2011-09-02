BEGIN TRANSACTION;
CREATE TABLE apero (id INTEGER PRIMARY KEY, text TEXT, trigger TEXT);
INSERT INTO apero VALUES(1,'Et une mouse pour %WHO%, santé :) | La bibine c''est pour %WHO%!|Une tournée pour %CHAN%!','^bie(re|er)$');
CREATE TABLE channels (ulimit NUMERIC, auto_mode , bot_mode TEXT, mode TEXT, bot_joined NUMERIC, password TEXT, created_by NUMERIC, active NUMERIC, created_on NUMERIC, type TEXT, owner NUMERIC, topic TEXT, auto_topic NUMERIC, auto_voice NUMERIC, auto_op NUMERIC, id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO channels VALUES(20,1,NULL,'stn',1,'plop',3,1,1314685151,'#',1,'J''aime les carambars!',3.72109477964358,NULL,5.89116090050997,1,'roots');
INSERT INTO channels VALUES(1,1,NULL,1,1,1,1,1,1,'#',3,1,1,1,1,2,'plop');
CREATE TABLE cooking_recipes (id INTEGER PRIMARY KEY, recipe TEXT, title TEXT, user_id NUMERIC);
INSERT INTO cooking_recipes VALUES(1,'Ingrédients

1 tomate grappe à decouper en morceaux et a faire fondre dans un peu d''huile (avec un peu d''oignons et d''ail revenus, evidemment!)
2 cs de vinaigre blanc
2 cs de sucre en poudre
1 cc de sauce soja
2 cs d''eau tiede
1/2 cc de maizena (facultatif, a dissoudre dans l''eau tiede)
Recette

Faire revenir une demi gousse d''ail écrasée et un peu d''oignon émincé dans un peu d''huile et ajouter la tomate, coupée en morceau - certains préfèrent peler la tomate auparavant et même l''épépiner. La version rustique (et feignante) laisse peau et pépin avec la tomate. Laisser fondre cette tomate 5-10 minutes sur feu doux

Mélanger tous les autres ingrédients aussi sur feu doux, dans l''odre, en mélangeant bien à chaque ajout et en terminant par l''eau (+ maizena)
Laisser épaissir 2 minutes sur feux doux puis transvaser dans un bol et laisser tiedir

Suggestion

Cette sauce accompagne à merveille les beignets de crevettes, les tempura en tout genre et les raviolis frits aux crevettes','Sauce aigre douce',1);
CREATE TABLE server_capabilities (id INTEGER PRIMARY KEY, key TEXT, value TEXT);
CREATE TABLE sessions (last_access NUMERIC, ignore NUMERIC, flood_numcmd NUMERIC, flood_end NUMERIC, flood_start NUMERIC, user TEXT, hostname TEXT, id INTEGER PRIMARY KEY, first_access NUMERIC, nick TEXT, user_id NUMERIC);
INSERT INTO sessions VALUES(1314946182,'',6,1314946209,1314946149,'~sho','74-68.61-188.cust.bluewin.ch',1,1314778822,'sho',3);
CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO test VALUES(1,'titi');
CREATE TABLE user_channel (auto_mode NUMERIC, channel_id NUMERIC, lvl NUMERIC, user_id NUMERIC);
CREATE TABLE users (is_bot NUMERIC, apikey_private TEXT, apikey TEXT, hostmask TEXT, pending NUMERIC, id INTEGER PRIMARY KEY, lvl NUMERIC, name TEXT, password TEXT);
INSERT INTO users VALUES(NULL,NULL,NULL,'*',0,1,1000,'admin','$6$4fdF$UvPxuI/jT3FOC1d7Q2Jl0jeRL.r5PnNWtZqxEDNczt9V0NOnOuTo0LLv/Nr1TTSVWkge43Txk/oj6.YjrdicC1');
INSERT INTO users VALUES(NULL,NULL,NULL,NULL,0,2,500,'tid','$6$4fdF$UvPxuI/jT3FOC1d7Q2Jl0jeRL.r5PnNWtZqxEDNczt9V0NOnOuTo0LLv/Nr1TTSVWkge43Txk/oj6.YjrdicC1');
INSERT INTO users VALUES(NULL,NULL,NULL,'*!*@*',0,3,800,'sho','$6$4fdF$UvPxuI/jT3FOC1d7Q2Jl0jeRL.r5PnNWtZqxEDNczt9V0NOnOuTo0LLv/Nr1TTSVWkge43Txk/oj6.YjrdicC1');
COMMIT;
