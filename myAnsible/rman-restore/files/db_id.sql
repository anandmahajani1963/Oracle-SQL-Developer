set head off feed off trimspool on line 80 pagesize 0
connect / as sysdba
select dbid from v$database;
exit;