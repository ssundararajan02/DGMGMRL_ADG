#!/bin/bash
#set -x
DATE=`date '+%Y%m%d_%H%M'`
DATE1=`date '+%Y%m%d:%H%M%S'`
export ORACLE_SID=$1
export ADG=$2
export script_dir='/home/oracle/stage'
export log_dir="$script_dir/log"
export log_file="$log_dir/$1_dg_disable_sync_$DATE.log"
export lock_file="$script_dir/dg_sync_$ORACLE_SID.lock"
export PATH=/usr/local/bin:$PATH
export ORATAB='/etc/oratab'
#export EMAILLIST='suresh.sundararajan@gilead.com'
export EMAILLIST='nandakumar.amarnath@gilead.com,SivaSankar.Chandran@gilead.com,Lingesan.Jeyapandy@gilead.com,suresh.sundararajan@gilead.com'
prereq_check()
{
if [ $# -ne 2 ]; then
        echo -e "\n \t Error in running the script \n Script Usage $0 <SID> <DR Name>\n
        Example: $0 ARGI8DEV SJ_ARGI8DEV_ADG" >> $log_file
        echo "Error"
        exit 1
   else
	touch $log_file
fi

if [ -f $log_file ] && [ -w $log_file ] ; then
                echo "Job started at `date +%d%m%Y:%H%M%S`" >> $log_file
                echo "---`date +%d%m%Y:%H%M%S` log_files are created in ==> $log_file" >> $log_file
		echo "Success"
        else
                echo "---`date +%d%m%Y:%H%M%S` Error in creating log_file file!! Please check and restart the Job" >> $log_file
                echo "Error"
                exit 1
fi
}

notify()
{
if [ "$1" != "Success" ]; then
        echo "DG Error at $2 - `date '+%Y%m%d:%H%M%S'`" >>  $log_file
        echo -e "$ORACLE_SID DG Error. \nplease check the log_files attached" | \
                mutt -s "$ORACLE_SID DG Error - $DATE" -a $log_file -- $EMAILLIST
        exit 0
#       mutt -e 'set content_type=text/html' -s "Error in running $2 job please check log_files" $EMAILLIST2 <$log_file
        elif [ "$2" == "END" ]; then
                echo  "---`date +%d%m%Y:%H%M%S` DR SYNC Disabled successfully  `date '+%Y%m%d:%H%M%S'`" >>  $log_file
                echo  "---`date +%d%m%Y:%H%M%S` Job Ended at `date +%d%m%Y:%H%M%S`" >>  $log_file
#               mailx -s "ARGUS Export Job $DT completed sccessfully" $EMAILLIST1
                echo -e "$ORACLE_SID DR SYNC Disabled successfully.  \n $msg \n log_file attached" | \
                     mutt -s "$ORACLE_SID DR SYNC Disabled successfully  - $DATE"  -a $log_file  -- $EMAILLIST
        else echo "---`date +%d%m%Y:%H%M%S` Proceeding with next step" >> $log_file
fi
}

#setting oracle DB environment variables
set_env()
{
ORA=$1
if [ -f "$ORATAB" ]; then
                echo "---`date +%d%m%Y:%H%M%S` $ORATAB Exists proceeding Further" >> $log_file
                echo "Success"
        else
                echo "---`date +%d%m%Y:%H%M%S` $ORATAB Not Exists, please check the oratab" >> $log_file
                echo "Error"
        exit 1
fi
SID_OTAP=$(cat $ORATAB |grep -v '(^#|^\*)' |grep \: |awk -F\: '{print $1}')
for i in $SID_OTAP
do
        if [ "$ORA" == "$i" ]; then
        otab="PASS"
        break
        else otab="FAIL"
        fi
done
if [ "$otab" == "PASS" ]; then
                export ORACLE_SID=$ORA
                export ORACLE_HOME=`cat /etc/oratab | grep -w $ORA | grep -v '^#'|awk -F ":" {'print $2'}`
                export ORAENV_ASK=NO
                . /usr/local/bin/oraenv > /dev/null
                export PATH=$PATH:$ORACLE_HOME/bin
        echo "---`date +%d%m%Y:%H%M%S` Environment set for $ORACLE_SID " >>$log_file
	echo "Success"
else
        echo "---`date +%d%m%Y:%H%M%S` Not in ORATAB add entry for $1 and restart" >> $log_file
        echo "Error"
        exit 1
fi
check_stat=`ps -ef|grep $ORA|grep pmon|wc -l`
oracle_num=`expr $check_stat`
if [ $oracle_num -lt 1 ]; then
        echo "---`date +%d%m%Y:%H%M%S` pmon $ORA is not running, start the instance and restart the job" >> $log_file
        echo "Error"
else
        echo "---`date +%d%m%Y:%H%M%S` pmon $ORA is running" >> $log_file
	echo "Success"
fi
}

check_instance_state()
{
#DBSTAT=$($ORACLE_HOME/bin/sqlplus -s "sys/$pass@$1 as sysdba" << EOF
DBSTAT=$($ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
                set pages 0 lin 150 feed off ver off head off echo off;
                                SET TRIMOUT ON;
                                SET TRIMSPOOL ON;
                col value for a150
                select status||'' from v\$instance;
exit;
EOF
)
if [[ $? = 0 ]] ; then
        if [[ "$DBSTAT" == "OPEN" ]]; then
        echo "---`date +%d%m%Y:%H%M%S` DB is in $DBSTAT state" >> $log_file
        echo "Success $DBSTAT"
        else
        echo "---`date +%d%m%Y:%H%M%S` DB is in $DBSTAT state" >> $log_file
        echo "Success $DBSTAT"
        fi
else
  echo "Error in Getting instance" >> $log_file
   echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
   echo "---END">> $log_file
   echo "Error"
fi
}

check_db_role()
{
#DBSTAT=$($ORACLE_HOME/bin/sqlplus -s "sys/$pass@$1 as sysdba" << EOF
DBSTAT=$($ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
                set pages 0 lin 150 feed off ver off head off echo off;
                                SET TRIMOUT ON;
                                SET TRIMSPOOL ON;
                col value for a150
                select case when DATABASE_ROLE='PRIMARY' then 'PRIMARY' else 'STANDBY' end||''  from v\$database;
exit;
EOF
)
if [[ $? = 0 ]] ; then
        if [[ "$DBSTAT" == "PRIMARY" ]]; then
        echo "---`date +%d%m%Y:%H%M%S` DB is primary database" >> $log_file
        echo "Success $DBSTAT"
        else
        echo "`date +%d%m%Y:%H%M%S` DB is Standby database" >> $log_file
        echo "Success $DBSTAT"
        fi
else
  echo "Error in Getting DB role" >> $log_file
   echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
   echo "---END">> $log_file
   echo "Error"
fi
}

#mount database
mount_db()
{
export failoverlog="$log_dir/failoverlog_`date '+%Y%m%d:%H%M%S'`.log"
#$ORACLE_HOME/bin/sqlplus -s "sys/$pass@$1 as sysdba" << EOF >> $failoverlog
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF >> $failoverlog
startup mount;
exit;
EOF

if [[ $? = 0 ]] ; then
   check_instance_state $1
else
  echo "Error in mounting DB" >> $log_file
   echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
   echo "---END">> $log_file
   echo "Error"
fi
}


##Show Current configuration
dg_conf()
{
echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
echo "##Show Current configuration" >> $log_file
$ORACLE_HOME/bin/dgmgrl / "show configuration verbose;" >> $log_file
echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
}

#dg_conf_status
dg_conf_stat()
{
echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
echo "---Checking Configuration Status">> $log_file
result=`echo "show configuration;" | \
  $ORACLE_HOME/bin/dgmgrl / | \
  grep -A 1 "Configuration Status" | grep -v "Configuration Status"|awk '{print $1}'`
if [ "$result" = "SUCCESS" ]  || [ "$result" = "WARNING" ] ; then
   echo "DG configuration status : $result" >> $log_file 
   echo "Success"
else
   echo "Error in DG configuration status is: $result" >> $log_file 
   echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
   echo "---END">> $log_file
   echo "Error" 
fi
}

##Checking Primary
dg_conf_prime()
{
echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
echo "---Checking Primary DB">> $log_file
PRIME=$($ORACLE_HOME/bin/dgmgrl / "show configuration;" |grep 'Primary'|awk '{print $1}')

if [[ $? = 0 ]] ; then
   echo "Primary DB is : -> $PRIME" >> $log_file 
   echo "Success $PRIME"
else
  echo "Error is not getting Primary DB Name " >> $log_file
   echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
   echo "---END">> $log_file
   echo "Error" 
fi
}

#Checking for standby
dg_conf_standby()
{
ADG=$1
echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
echo "---Checking Standby DB">> $log_file
STD=$($ORACLE_HOME/bin/dgmgrl / "show configuration;" |grep -i  'standby'|awk '{print $1}'|grep $ADG)
if [[ $? = 0 ]] ; then
   echo "Standby DB is : -> $STD" >> $log_file
   echo "Success $STD"
else
  echo "Error in Standby DB " >> $log_file
   echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
   echo "---END">> $log_file
   echo "Error"
fi

}

#Checking standby apply state
dg_apply_stat()
{
ADG=$1
echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
echo "---Checking Standby Apply state">> $log_file
APPLYSTATE=$($ORACLE_HOME/bin/dgmgrl / "show database  '$ADG';"|grep 'Intended State'|awk '{print $(NF)}')
echo $APPLYSTATE
}

dg_sync_stat()
{
ADG=$1
echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
echo "---Checking Standby Apply SYNC State">> $log_file
lag_value=$($ORACLE_HOME/bin/dgmgrl / "show database  '$ADG';"|grep 'Apply Lag')
echo $lag_value >>  $log_file
time_value=`echo "$lag_value"|cut -d " " -f 14`
time_param=`echo "$lag_value"|cut -d " " -f 15`
echo $lag_value 
echo "DR Apply Lag Time" >> $log_file
echo "$lag_value" >> $log_file
if [[ "$time_param" == "hour(s)" && "$time_value" -ge 0 ]]
then
    echo "Error" "$lag_value"
elif [[ "$time_param" == minute* && "$time_value" -ge 16 ]]
then
    echo "Error" "$lag_value" 
elif [[ "$time_param" == minute* && "$time_value" -le 2 ]]
then
    echo "Success" "NoLag"
else
    echo "Error" "$lag_value"     
fi
}



#Disable DG sync for ActiveDataGurad
#Creates Lock File
dg_dsiable_adg()
{
export adglog="$log_dir/adglog_`date '+%Y%m%d:%H%M%S'`.log"
echo "---`date '+%Y%m%d:%H%M%S'`">> $log_file
echo "---Disable ADG SYNC ">> $log_file
$ORACLE_HOME/bin/dgmgrl / "edit database '$1' set state='apply-off';" > $adglog
adg_status=`cat $adglog|grep -w Succeeded |tr -d \,|wc -l`

if [ $adg_status = 1 ];then
                echo "DR SYNC has been disabled for $ADG_NAME" >> $log_file
		echo $$ > $lock_file
		echo "Lock file $lock_file created" >> $log_file
   		echo "Success"
        else
                echo "Error in Disabling DR SYNC for $ADG_NAME" >> $log_file
   		echo "Error" 
fi
}

#main
precheck=`prereq_check $1 $2`
echo $precheck
notify $precheck "Pre-check"
setenv=`set_env $1`
set_env $1
echo $setenv
notify $setenv "Pre-check"
dg_conf
dg_stat=`dg_conf_stat`
echo $dg_stat
notify $dg_stat "DG_Config"
dg_prime=`dg_conf_prime`
PRIME_NAME=`echo $dg_prime|awk '{ print $2}'`
echo $dg_prime
notify $dg_prime "DG_Primary"
dg_stadby=`dg_conf_standby $2`
ADG_NAME=`echo $dg_stadby|awk '{ print $2}'`
echo $dg_stadby
notify $dg_stadby "ADG_Standby"
dg_check_apply=`dg_apply_stat $2`
echo $dg_check_apply
if [[ "$dg_check_apply" = "APPLY-ON" ]] ; then
	echo "DR Replication is enabled :-> $dg_check_apply" >> $log_file
	adg_disable=`dg_dsiable_adg $ADG_NAME`
	echo $adg_disable
	notify $adg_disable "Disable DR SYNC"
	notify $adg_disable "END"
elif [[ "$dg_check_apply" = "APPLY-OFF" ]] ; then
	echo "DR Replication is already disabled :-> $dg_check_apply" >> $log_file
	dg_lag=`dg_sync_stat $ADG_NAME`
	echo "Apply Lag status $dg_lag" >>$log_file
	notify "Error" "DR is already disabled"
else
	echo "Error in Replication state :-> $dg_check_apply" >> $log_file
	dg_lag=`dg_sync_stat $ADG_NAME`
	echo "Apply Lag status $dg_lag" >>$log_file
	notify "Error" "Error in DB replication status"
fi

#END
