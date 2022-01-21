#!/bin/ksh 
  
# AUDIT ARCHIVE SCRIPT 
# 
# Last Updated: Jan-2022 (a1ds/mxkq) 
  
if [ -z "$1" ] ; then 
  echo "Usage: auditarc.sh sid" 
  exit 1 
fi 
  
. ~/.bash_profile 
export ORACLE_SID=$1 
ORAENV_ASK="NO" 
. /usr/local/bin/oraenv 
ORAENV_ASK="YES" 
  
# set these per db 
EMAIL="`cat $HOME/scripts/.oradbaid`" 
SCRDIR=$HOME/scripts 
cd $SCRDIR 
  
DTAG=`date +%Y%m%d.%H%M` 
SCRID="$SCRDIR"/`basename $0` 
SCRLOG=${SCRDIR}/logs/`basename $0`."$ORACLE_SID"."$DTAG".log 
DRP_PARTITION=/tmp/drp_partition_$$.sql 
DRP_PART_LOG=/tmp/db_part_log_$$.log 
MAILID=`hostname`:"$ORACLE_SID" 
  
( 
date 
#echo 
  
sqlplus -s << EOF 
/ as sysdba 
set serveroutput on size 1000000 
set trimout on 
set linesize 120 
  
DECLARE 
     num_aud   number; 
     num_arch  number; 
 
BEGIN 
  
--archive data 
insert into system.audit_archive 
(select * from sys.aud$ 
  where trunc(ntimestamp#) < (trunc(sysdate)) ); 
  
num_arch := to_char(SQL%ROWCOUNT); 
dbms_output.put_line(num_arch || ' rows copied to audit_archive'); 
  
--delete old 
delete from sys.aud$ 
where trunc(ntimestamp#) < (trunc(sysdate)); 
  
num_aud := to_char(SQL%ROWCOUNT); 
dbms_output.put_line(num_aud || ' rows deleted from aud$'); 
  
if num_aud = num_arch then 
  COMMIT; 
else 
  dbms_output.put_line('WARNING - copy is rolled back: rows archived not equal to rows deleted'); 
  ROLLBACK; 
end if; 
  
EXCEPTION 
  WHEN OTHERS THEN 
     dbms_output.put_line('auditarc.sh SQL ERROR: ' || sqlerrm); 
     ROLLBACK; 
END; 
/ 
EOF 
  
AUDIT_DEST=`sqlplus -s /nolog <<EOFC 
        connect / as sysdba 
        set pagesize 0 feedback off verify off heading off echo off 
        select value from v\\$parameter where name='audit_file_dest'; 
        exit; 
        EOFC` 
  
echo 
echo "Audit files Delete > date: " 
find ${AUDIT_DEST} -mtime +396 -exec rm -f {} \; 
echo 
echo "Audit files Oldest: " 
ls -ltr ${AUDIT_DEST} | head -n 2 
echo 
ASIZE=`du -k ${AUDIT_DEST} | cut -f1` 
echo AUDIT Directory kb size: "$ASIZE" 
if [ "$ASIZE" -gt 13000000 ] ; then 
  echo "WARNING: Audit directory size $ASIZE exceeds max kb size 10000 mb" 
fi 
  
  
) > $SCRLOG 2>&1 
sleep 3 
  
sqlplus -s /nolog << EOFA 
connect / as sysdba 
set feedback off echo off heading off verify off 
spool $DRP_PARTITION 
select 'alter table SYSTEM.AUDIT_ARCHIVE drop partition '||partition_name||';' from 
( 
select table_name, 
       partition_name, 
       to_date ( 
          trim ( 
             '''' from regexp_substr ( 
                          extractvalue ( 
                             dbms_xmlgen. 
                             getxmltype ( 
                                'select high_value from dba_tab_partitions where table_name=''' 
                                || table_name 
                                || ''' and table_owner = ''' 
                                || table_owner 
                                || ''' and partition_name = ''' 
                                || partition_name 
                                || ''''), 
                             '//text()'), 
                          '''.*?''')), 
          'syyyy-mm-dd hh24:mi:ss') 
          high_value_in_date_format 
  from dba_tab_partitions 
where table_name = 'AUDIT_ARCHIVE' and table_owner = 'SYSTEM' and partition_position > 1 
) where high_value_in_date_format< sysdate-396; 
spool off 
exit; 
EOFA 
  
if [ -s "$DRP_PARTITION" ] ; 
then 
sqlplus /nolog <<EOFB 
connect / as sysdba 
set echo on 
spool $DRP_PART_LOG 
@$DRP_PARTITION 
spool off 
exit; 
EOFB 
else 
echo "">$DRP_PART_LOG 
echo "No Partition for Table AUDIT_ARCHIVE exist with data older than 13 months.">>$DRP_PART_LOG 
echo "">>$DRP_PART_LOG 
fi 
  
cat $DRP_PART_LOG|grep -v "$DRP_PARTITION" >> $SCRLOG 
date >> $SCRLOG 
echo "========END=========" >> $SCRLOG 
  
# ---------------------------------- 
LOGSTAT=`awk '/ERROR/ || /WARNING/ || /ORA-/ ' "$SCRLOG" ` 
  
if [ -n "$LOGSTAT" ] ; then 
echo "Emailing Log WARNING/ERROR: $LOGSTAT" >> $SCRLOG 
echo "There are WARNING/ERROR Found: $LOGSTAT" >> $SCRLOG 
mailx -s "FAILURE:$MAILID Audit Purge Details" "$EMAIL" < $SCRLOG 
else 
  echo "No ERROR/WARNING Found" >> $SCRLOG 
mailx -s "SUCCESS:$MAILID Audit Purge Details" "$EMAIL" < $SCRLOG 
fi 
  
rm $DRP_PARTITION $DRP_PART_LOG 
exit; 
 
