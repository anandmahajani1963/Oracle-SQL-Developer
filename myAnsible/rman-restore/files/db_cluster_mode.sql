set head off feed off trimspool on line 80 pagesize 0
connect / as sysdba
select value from v$parameter where name = 'cluster_database';
exit;

