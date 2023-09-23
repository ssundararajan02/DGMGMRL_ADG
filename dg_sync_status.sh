#!/bin/bash
set -x
DATE=`date '+%Y%m%d_%H%M'`
DATE1=`date '+%Y%m%d_%H%M%S'`
export ORACLE_SID=$1
export ADG=$2
export script_dir='/home/oracle/stage'
export log_dir="$script_dir/log"
export log_file="$log_dir/$1_dg_sync_status_$DATE.log"
export PATH=/usr/local/bin:$PATH
export ORATAB='/etc/oratab'
export EMAILLIST='suresh.sundararajan@gilead.com'
export RUN_APP_PKG=true
prereq_check()
{
if [ $# -ne 2 ]; then
        echo -e "\n \t Error in running the script \n Script Usage $0 <SID> <DR Name>\n" >> $log_file
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
        echo "DG Error at $2 - `date '+%Y%m%d_%H%M%S'`" >>  $log_file
        echo -e "$ORACLE_SID DG Error. \nplease check the log_files attached" | \
                mutt -s "$ORACLE_SID DG Error - $DATE" -a $log_file -- $EMAILLIST
        exit 0
#       mutt -e 'set content_type=text/html' -s "Error in running $2 job please check log_files" $EMAILLIST2 <$log_file
        elif [ "$2" == "END" ]; then
                echo  "---`date +%d%m%Y:%H%M%S` DR is in SYNC `date '+%Y%m%d_%H%M%S'`" >>  $log_file
                echo  "---`date +%d%m%Y:%H%M%S` Job Ended at `date +%d%m%Y:%H%M%S`" >>  $log_file
#               mailx -s "ARGUS Export Job $DT completed sccessfully" $EMAILLIST1
                echo -e "$ORACLE_SID DR is SYNC \n $msg \n log_file attached" | \
                     mutt -s "$ORACLE_SID DR is SYNC - $DATE"  -a $log_file  -- $EMAILLIST
                if [[ "$RUN_APP_PKG" == true ]]; then
                        run_app_script
                fi
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
        echo "`date +%d%m%Y:%H%M%S` Not in ORATAB add entry for $1 and restart" >> $log_file
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

dg_sync_stat()
{
ADG=$1
echo "---`date '+%Y%m%d_%H%M%S'`">> $log_file
echo "---Checking Standby Apply SYNC State">> $log_file
lag_value=$($ORACLE_HOME/bin/dgmgrl / "show database  '$ADG';"|grep 'Apply Lag')
echo $lag_value >>  $log_file
time_value=`echo "$lag_value"|cut -d " " -f 14`
time_param=`echo "$lag_value"|cut -d " " -f 15`
echo "DR Apply Lag Time" >> $log_file
echo "$lag_value" >> $log_file


if [[ "$time_param" == hour* && "$time_value" -ge 0 ]]
then
echo "Error" "$time_param" 
elif [[ "$time_param" == minute* && "$time_value" -ge 5 ]]
then
echo "Error" "$time_param" 
else 
	echo "Success" "NoLag"
fi
}

run_app_script()
{
echo "---`date '+%Y%m%d_%H%M%S'`">> $log_file
echo "---Executing GILEAD_AI.P_REPLICATION_VERIFICATION">> $log_file
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF >>$log_file
                set pages 0 lin 150 feed off ver off head off echo off;
                SET TRIMOUT ON;
                SET TRIMSPOOL ON;
                col value for a150
                BEGIN
                        GILEAD_AI.P_REPLICATION_VERIFICATION();
                END;
                /
exit;
EOF

if [[ $? = 0 ]] ; then
echo "---`date '+%Y%m%d_%H%M%S'`">> $log_file
echo "---GILEAD_AI.P_REPLICATION_VERIFICATION Executed successfully" >> $log_file
echo "---`date '+%Y%m%d_%H%M%S'`">> $log_file
else
echo "---`date '+%Y%m%d_%H%M%S'`">> $log_file
echo "---Error in executing GILEAD_AI.P_REPLICATION_VERIFICATION" >> $log_file
echo "---`date '+%Y%m%d_%H%M%S'`">> $log_file
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
export DRDB=$2

dg_sync()
{
dr_sync_status=`dg_sync_stat $DRDB`
echo $dr_sync_status
dr_lag=`echo $dr_sync_status|awk '{print $2}'`
}

dg_sync
for i in {1..15}
do
	if [[ "$dr_lag" == "NoLag" ]]; then
	notify "Success" "$dr_lag"
	notify "Success" "END"
        break
	elif [[ "$dr_lag" == hour* ]]; then
	sleep 300 
	dg_sync
	elif [[ "$dr_lag" == minute* ]]; then
	sleep 120 
	dg_sync
	fi
	if [ $i = 15 ]; then
	notify "Error" "DR is not SYNC"
	fi
	
done
#END
