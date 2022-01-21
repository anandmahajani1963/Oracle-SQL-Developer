-- Relocate Audit table from SYSTEM to SYSAUX tablespace
set echo on
spool /home/oracle/scripts/logs/reloacate_aud_table.log
connect / as sysdba
Begin 
  DBMS_AUDIT_MGMT.SET_AUDIT_TRAIL_LOCATION ( 
    audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_DB_STD, 
    audit_trail_location_value => 'SYSAUX');
END; 
/ 
spool off
exit
