-------------------------------------------------------------------------------
-- Author       Gleb Otochkin
-- Created      2015-04-15
-- Purpose      Upload information about schemas to a flat file before migration for future comparison
--                      Required directory and file name to be specified.
-- Usage        @validation.sql <directory_name> <file name> <list of schemas>
-- Example:     echo -e "'MY_DIRECTORY'\n'my_file.out'\n'SCOTT'" | sqlplus / as sysdba @validation.sql
-------------------------------------------------------------------------------
-- Modification History
-- 2021-07-15 - Modified the where clause for the tables - Gleb Otochkin
-- 2021-07-15 - Added Example to usage  - Gleb Otochkin
-------------------------------------------------------------------------------
DECLARE
  t_command       VARCHAR2(200);
  t_cid           INTEGER;
  t_total_records NUMBER(10);
  stat            INTEGER;
  row_count       INTEGER;
  t_limit         INTEGER := 0;    -- Only show tables with more rows
  my_file         UTL_FILE.FILE_TYPE;
  my_dir          VARCHAR2(40);
  my_file_name    VARCHAR2(50);
  my_time         VARCHAR2(50);
 BEGIN
  t_limit := 1;
  my_dir := &1;
  my_file_name := &2;
my_file:=UTL_FILE.FOPEN(my_dir,my_file_name,'w');
select to_char(sysdate,'mm/dd/yyyy hh24:mi:ss') into my_time from dual;
UTL_FILE.PUT_LINE(my_file,'START_TIME: '||my_time);
UTL_FILE.PUT_LINE(my_file,'TABLES:');
  for t1 in (SELECT owner,table_name FROM dba_tables where owner in (&&3)
AND external='NO' and iot_name is null ORDER BY owner, table_name)
  LOOP

        t_command := 'SELECT /*+ parallel(4) */ COUNT(*) FROM '||t1.owner||'.'||t1.table_name;
        t_cid := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(t_cid,t_command,DBMS_SQL.native);
        DBMS_SQL.DEFINE_COLUMN(t_cid,1,t_total_records);
        stat := DBMS_SQL.EXECUTE(t_cid);
        row_count := DBMS_SQL.FETCH_ROWS(t_cid);
        DBMS_SQL.COLUMN_VALUE(t_cid,1,t_total_records);
        --IF t_total_records > t_limit THEN
                UTL_FILE.PUT_LINE(my_file,RPAD(t1.owner||'.'||t1.table_name,55,' ')||
                        TO_CHAR(t_total_records,'99999999')||' record(s)');
        --END IF;
        DBMS_SQL.CLOSE_CURSOR(t_cid);
  END LOOP;
UTL_FILE.PUT_LINE(my_file,'INDEXES:');
  for i1 in (select owner,table_name,index_name,status from dba_indexes where owner in (&&3) and table_name not like 'BIN%' and index_name not like 'SYS_IL%' ORDER BY owner, table_name, index_name)
  LOOP
        UTL_FILE.PUT_LINE(my_file,RPAD(i1.owner||'.'||i1.table_name,55,' ')||
                             RPAD(i1.index_name,35,' ')||i1.status);
  END LOOP;
UTL_FILE.PUT_LINE(my_file,'CONSTRAINTS:');
  for c1 in (select owner,table_name,case when constraint_name like 'SYS%' then 'SYS' else constraint_name end as constraint_name,constraint_type,status from dba_constraints where owner in (&&3) and constraint_name not like 'BIN%' and constraint_type !='?' ORDER BY owner, table_name, constraint_name)
  LOOP
        UTL_FILE.PUT_LINE(my_file,RPAD(c1.owner||'.'||c1.table_name,55,' ')||
                             RPAD(c1.constraint_name,35,' ')||c1.status);
  END LOOP;
UTL_FILE.PUT_LINE(my_file,'TRIGGERS:');
  for tr1 in (select owner,trigger_name,table_name,status from dba_triggers  where owner in (&&3) ORDER BY owner, table_name, trigger_name)
  LOOP
        UTL_FILE.PUT_LINE(my_file,RPAD(tr1.owner||'.'||tr1.table_name,55,' ')||
                             RPAD(tr1.trigger_name,35,' ')||tr1.status);
  END LOOP;
UTL_FILE.PUT_LINE(my_file,'SEQUENCES:');
  for seq1 in (select sequence_owner,sequence_name,increment_by,cache_size,last_number from dba_sequences  where sequence_owner in (&&3) ORDER BY  sequence_owner,sequence_name)
  LOOP
        UTL_FILE.PUT_LINE(my_file,RPAD(seq1.sequence_owner||'.'||seq1.sequence_name,55,' ')||
                             RPAD(to_char(seq1.increment_by),12,' ')||
                             RPAD(to_char(seq1.cache_size),12,' ')||
                             to_char(seq1.last_number));
  END LOOP;
select to_char(sysdate,'mm/dd/yyyy hh24:mi:ss') into my_time from dual;
UTL_FILE.PUT_LINE(my_file,'END_TIME: '||my_time);
UTL_FILE.FCLOSE(my_file);
END;
/

