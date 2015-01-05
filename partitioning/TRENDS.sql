/*
This is DRAFT.
It doesn't translated to English and checked for missprints and errors.
*/

-- Every potentially danger command is commented out with triple minus (-) symbol
-- Каждая потенциально опасная команда закоментирована тройным символом минус (-)
--
-- Let's start from the smallest table - TRENDS
-- Начнем с самой маленькой таблицы - TRENDS
--
-- First, gather statistics from source table
-- Собираем статистику с исходной таблицы
--
EXEC dbms_stats.gather_table_stats('&&SCHEMA', 'TRENDS', cascade => true);
--
-- Next, check for existing of table TRENDS2
-- Далее, проверим на наличие таблицы TRENDS2
--
SELECT  TABLE_NAME 
FROM    ALL_TABLES
WHERE   TABLE_NAME = 'TRENDS2';
--
-- Result must be NULL.
-- В результате должен быть NULL.
--
-- Drop temporary table TRENDS2 inculding all CONSTRAINTS
-- Удаляем временную таблицу TRENDS2 вместе со всеми ограничениями
-- Double dot (.) here - it is SQL syntax
-- Две точки (.) тут  - такой синтаксис
--
--- drop table &&SCHEMA..TRENDS2 cascade CONSTRAINTS;
--
--
-- Let's create temporary table, based on the original one
-- Cоздаем временную таблицу на основе оригинальной
--
-- Creating based on original data scheme of zabbix 2.0.6 database
-- (взято из схемы от zabbix 2.0.6)
--
-- PRIMARY KEY we'll create later
-- PRIMARY KEY будет позже
--
CREATE TABLE &&SCHEMA..TRENDS2 (
  itemid     number(20)                      NOT NULL,
  clock      number(10)    DEFAULT '0'       NOT NULL,
  num        number(10)    DEFAULT '0'       NOT NULL,
  value_min  number(20,4)  DEFAULT '0,0000'  NOT NULL,
  value_avg  number(20,4)  DEFAULT '0,0000'  NOT NULL,
  value_max  number(20,4)  DEFAULT '0,0000'  NOT NULL)
TABLESPACE ZAB_DATA
COMPRESS PARTITION BY RANGE(clock)
(PARTITION TRENDS_201401 VALUES LESS THAN(1391212800) TABLESPACE ZABBIX_201401,
 PARTITION TRENDS_201402 VALUES LESS THAN(1393632000) TABLESPACE ZABBIX_201402,
 PARTITION TRENDS_201403 VALUES LESS THAN(1396310400) TABLESPACE ZABBIX_201403,
 PARTITION TRENDS_201404 VALUES LESS THAN(1398902400) TABLESPACE ZABBIX_201404,
 PARTITION TRENDS_201405 VALUES LESS THAN(1401580800) TABLESPACE ZABBIX_201405,
 PARTITION TRENDS_201406 VALUES LESS THAN(1404172800) TABLESPACE ZABBIX_201406,
 PARTITION TRENDS_201407 VALUES LESS THAN(1406851200) TABLESPACE ZABBIX_201407,
 PARTITION TRENDS_201408 VALUES LESS THAN(1409529600) TABLESPACE ZABBIX_201408,
 PARTITION TRENDS_201409 VALUES LESS THAN(1412121600) TABLESPACE ZABBIX_201409,
 PARTITION TRENDS_201410 VALUES LESS THAN(1414800000) TABLESPACE ZABBIX_201410,
 PARTITION TRENDS_201411 VALUES LESS THAN(1417392000) TABLESPACE ZABBIX_201411,
 PARTITION TRENDS_201412 VALUES LESS THAN(1420070400) TABLESPACE ZABBIX_201412,
 PARTITION TRENDS_201501 VALUES LESS THAN(1422748800) TABLESPACE ZABBIX_201501,
 PARTITION TRENDS_201502 VALUES LESS THAN(1425168000) TABLESPACE ZABBIX_201502,
 PARTITION TRENDS_201503 VALUES LESS THAN(1427846400) TABLESPACE ZABBIX_201503,
 PARTITION TRENDS_201504 VALUES LESS THAN(1430438400) TABLESPACE ZABBIX_201504,
 PARTITION TRENDS_201505 VALUES LESS THAN(1433116800) TABLESPACE ZABBIX_201505,
 PARTITION TRENDS_201506 VALUES LESS THAN(1435708800) TABLESPACE ZABBIX_201506,
 PARTITION TRENDS_201507 VALUES LESS THAN(1438387200) TABLESPACE ZABBIX_201507,
 PARTITION TRENDS_201508 VALUES LESS THAN(1441065600) TABLESPACE ZABBIX_201508,
 PARTITION TRENDS_201509 VALUES LESS THAN(1443657600) TABLESPACE ZABBIX_201509,
 PARTITION TRENDS_201510 VALUES LESS THAN(1446336000) TABLESPACE ZABBIX_201510,
 PARTITION TRENDS_201511 VALUES LESS THAN(1448928000) TABLESPACE ZABBIX_201511,
 PARTITION TRENDS_201512 VALUES LESS THAN(1451606400) TABLESPACE ZABBIX_201512,
 PARTITION TRENDS_ALL    VALUES LESS THAN(MAXVALUE)   TABLESPACE ZAB_DATA);
--
-- Here we begin to copy (redefine) data from one table to another
-- Тут начинается процесс переноса данных из одной таблицы в другую.
--
-- First checking the possibility
-- Сначала проверяем саму возможность 
--
EXEC Dbms_Redefinition.Can_Redef_Table('&&SCHEMA', 'TRENDS');
--
-- If we got no error, then let's begin redefenition. It'll take some time.
-- Если ошибок не было, то начинаем процесс
--
BEGIN
  DBMS_REDEFINITION.start_redef_table(
    uname      => '&&SCHEMA',        
    orig_table => 'TRENDS',
    int_table  => 'TRENDS2');
END;
/
--
-- stop-here --
--
-- Т.к. мы не сидели и не медитировали на процесс, то неизвестно, давно ли он закончился
-- Поэтому синхронизируем таблицы

BEGIN
  dbms_redefinition.sync_interim_table(
    uname      => '&&SCHEMA',        
    orig_table => 'TRENDS',
    int_table  => 'TRENDS2');
END;
/


/*
BEGIN
  DBMS_REDEFINITION.ABORT_REDEF_TABLE(
    uname        => '&&SCHEMA',                     -- schema name
    orig_table   => 'TRENDS',  -- table to redefine
    int_table    => 'TRENDS2'); -- interim table
END;
/
*/
-- И создаем всякие зависимости
-- Притом из-за бага в 11.2.0.3 
-- http://oracledoug.com/serendipity/index.php?/archives/1685-11.2.0.3-Interval-Partitioning-Constraint-Creation-Bug.html
-- 14230768
-- сначала создаем индексы и только потом ключи добавляем
CREATE INDEX &&SCHEMA..TRENDS2_IX on &&SCHEMA..TRENDS2 (itemid,clock) LOCAL;

ALTER TABLE &&SCHEMA..TRENDS2 ADD 
  CONSTRAINT TRENDS2_IX PRIMARY KEY (itemid,clock);

-- Заканчиваем процесс копирования
BEGIN
  dbms_redefinition.finish_redef_table(
    uname      => '&&SCHEMA',        
    orig_table => 'TRENDS',
    int_table  => 'TRENDS2');
END;
/
-- Теперь наша таблица TRENDS2 стала основной и имеет имя TRENDS
-- ну и наоборот
-- поэтому старую удаляем
DROP TABLE &&SCHEMA..TRENDS2 CASCADE CONSTRAINTS;
ALTER TABLE &&SCHEMA..TRENDS RENAME CONSTRAINT TRENDS2_IX to TRENDS_IX;
ALTER INDEX &&SCHEMA..TRENDS2_IX RENAME TO TRENDS_IX;

-- Собираем статистику с вновь созданной таблицы
exec dbms_stats.gather_table_stats('&&SCHEMA', 'TRENDS', cascade => true);

-- Проверям, что у нас появились partitions в нашей таблице
SELECT partitioned
FROM   all_tables
WHERE  table_name = 'TRENDS';

-- И названия самих partitions
SELECT partition_name
FROM   all_tab_partitions
WHERE  table_name = 'TRENDS';

-- Так мы получим размер партиций нашей таблицы в мегабайтах
-- а также размер индекса
SELECT    seg.segment_name OBJECT, 
          seg.partition_name,
          par.table_name,
          seg.TABLESPACE_NAME, 
          ROUND (seg.BYTES / 1024 / 1024, 2) "size_in_Mb"
FROM     dba_segments       seg, 
         ALL_TAB_PARTITIONS par
WHERE    segment_type IN ('TABLE', 'TABLE PARTITION') 
AND      seg.owner = '&&SCHEMA'
AND      par.table_name='TRENDS'
AND      par.partition_name=seg.partition_name;

SELECT    seg.segment_name OBJECT, 
          seg.partition_name,
          par.index_name,
          seg.TABLESPACE_NAME, 
          ROUND (seg.BYTES / 1024 / 1024, 2) "size_in_Mb"
FROM     dba_segments       seg, 
         DBA_IND_PARTITIONS par
WHERE    segment_type IN ('INDEX', 'INDEX PARTITION') 
AND      seg.owner = '&&SCHEMA'
AND      par.index_name like 'TRENDS%'
AND      par.partition_name=seg.partition_name;

