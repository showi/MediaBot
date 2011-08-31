BEGIN TRANSACTION;
CREATE TABLE apero (id INTEGER PRIMARY KEY, text TEXT, trigger TEXT);
INSERT INTO apero VALUES(1,'Et une mouse pour %WHO%, santé :) | La bibine c''est pour %WHO%!|Une tournée pour %CHAN%!','^bie(re|er)$');
CREATE TABLE channels (mode TEXT, bot_joined NUMERIC, password TEXT, created_by NUMERIC, active NUMERIC, created_on NUMERIC, type TEXT, owner NUMERIC, topic TEXT, auto_topic NUMERIC, auto_voice NUMERIC, auto_op NUMERIC, id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO channels VALUES(NULL,1,NULL,3,1,1314684470,'#',NULL,NULL,NULL,NULL,NULL,1,'roots');
INSERT INTO channels VALUES(NULL,1,NULL,3,1,1314684674,'#',3,NULL,NULL,NULL,NULL,2,'nos');
INSERT INTO channels VALUES(NULL,1,NULL,3,1,1314685151,'#',NULL,NULL,NULL,NULL,NULL,3,'nose');
INSERT INTO channels VALUES(NULL,1,NULL,3,1,1314685243,'#',2,NULL,NULL,NULL,NULL,4,'olie');
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
INSERT INTO sessions VALUES(1314779356,NULL,5,1314779359,1314779299,'~sho','74-68.61-188.cust.bluewin.ch',1,1314778822,'sho',3);
CREATE TABLE user_channel (auto_mode NUMERIC, channel_id NUMERIC, lvl NUMERIC, user_id NUMERIC);
CREATE TABLE users (hostmask TEXT, pending NUMERIC, id INTEGER PRIMARY KEY, lvl NUMERIC, name TEXT, password TEXT);
INSERT INTO users VALUES('*',0,1,1000,'admin','$6$4fdF$UvPxuI/jT3FOC1d7Q2Jl0jeRL.r5PnNWtZqxEDNczt9V0NOnOuTo0LLv/Nr1TTSVWkge43Txk/oj6.YjrdicC1');
INSERT INTO users VALUES(NULL,0,2,500,'tid','$6$4fdF$UvPxuI/jT3FOC1d7Q2Jl0jeRL.r5PnNWtZqxEDNczt9V0NOnOuTo0LLv/Nr1TTSVWkge43Txk/oj6.YjrdicC1');
INSERT INTO users VALUES('*!*@*',0,3,800,'sho','$6$4fdF$UvPxuI/jT3FOC1d7Q2Jl0jeRL.r5PnNWtZqxEDNczt9V0NOnOuTo0LLv/Nr1TTSVWkge43Txk/oj6.YjrdicC1');
INSERT INTO users VALUES('gains*!gainsbarre@*.wanadoo.fr',0,4,800,'gainsbarre','$6$4fdF$M8nysgEOpootlOUaZJGWgN.MliY37DAJUcVohh8kJ.IWVwxMA.x4/qH5C3RIbVrhmR7SOvysOcV0.BSCG7v3u0');
COMMIT;
