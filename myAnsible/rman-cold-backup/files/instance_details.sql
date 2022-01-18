set head off feed off trimspool on line 120 pagesize 0
connect / as sysdba
select inst_id, instance_name, host_name from gv$instance;
exit;

