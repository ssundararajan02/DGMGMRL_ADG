#!/bin/bash
log_file='demo.log'
ADG_NAME='SJ_ARGI8TST_ADG'
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
elif [[ "$time_param" == minute* && "$time_value" -ge 1 ]]
then
    echo "Error" "$lag_value" 
else
	    echo "Success" "NoLag"
fi

}

dg_lag=`dg_sync_stat $ADG_NAME`
echo "Apply Lag status $dg_lag"