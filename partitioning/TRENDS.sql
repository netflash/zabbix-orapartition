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

EXEC dbms_stats.gather_table_stats('&&SCHEMA', 'TRENDS', cascade => true);

-- Next, check for existing of table TRENDS2
-- Далее, проверим на наличие таблицы TRENDS2

SELECT  TABLE_NAME 
FROM    ALL_TABLES
WHERE   TABLE_NAME = 'TRENDS2';

-- Result must be NULL.
-- В результате должен быть NULL.
--
-- Drop temporary table TRENDS2 inculding all CONSTRAINTS
-- Удаляем временную таблицу TRENDS2 вместе со всеми ограничениями
-- Double dot (.) here - it is SQL syntax
-- Две точки (.) тут  - такой синтаксис

--- drop table &&SCHEMA..TRENDS2 cascade CONSTRAINTS;

-- получаем самое маленькое значение clock
select min(clock) from &&SCHEMA..TRENDS;

-- для меня это 1361592000
-- используем http://www.onlineconversion.com/unix_time.htm конвертер и получаем
-- Sat, 23 Feb 2013 04:00:00 GMT
-- Соответственно начнем с 1 апреля 2013 
-- это в unixtime = 1364774400 и далее партиции по 1 неделе
-- это значение 604800
--
-- Cоздаем временную таблицу на основе оригинальной
-- (взято из схемы от zabbix 2.0.6)
-- PRIMARY KEY будет позже
CREATE TABLE &&SCHEMA..TRENDS2 (
itemid                   number(20)                                NOT NULL,
        clock                    number(10)      DEFAULT '0'               NOT NULL,
        num                      number(10)      DEFAULT '0'               NOT NULL,
        value_min                number(20,4)    DEFAULT '0,0000'          NOT NULL,
        value_avg                number(20,4)    DEFAULT '0,0000'          NOT NULL,
        value_max                number(20,4)    DEFAULT '0,0000'          NOT NULL
)
COMPRESS PARTITION BY RANGE(clock)
INTERVAL(604800)
(PARTITION p0_trends VALUES LESS THAN(1364774400));
-- Тут начинается процесс переноса данных из одной таблицы в другую.
-- Сначала проверяем саму возможность 
EXEC Dbms_Redefinition.Can_Redef_Table('&&SCHEMA', 'TRENDS');

-- Если ошибок не было, то начинаем процесс
BEGIN
  DBMS_REDEFINITION.start_redef_table(
    uname      => '&&SCHEMA',        
    orig_table => 'TRENDS',
    int_table  => 'TRENDS2');
END;
/

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
