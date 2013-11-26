#!/bin/bash

optspec=":medx:"

OPTIND=1

while getopts "$optspec" optx; do
    case "${optx}" in 
	m)
	    morning=1
	    script_name="bt_manual_recon_morning_script.py"
	    csv_files=(
		contacts_XX
		locations_XX
		subscriptions_XX
		done_customers_XX
	    )
	    ;;
	e)
	    script_name="bt_manual_recon_evening_script.py"
	    csv_files=(
		bt_manual_recon_morning_XX_JM
		done_customers_XX
	    )
	    ;;
	d)
	    dry_run=1
	    ;;
	x)
	    iteration=$OPTARG
	    ;;
    esac
done

cd ~/envs/spdj
echo -e "\n[ Getting files... ]"

# ${csv_files[*]} flattens the array into one string
# If unquoted, both subscripts * and @ expand to the same result, 
# if quoted, @ expands to all elements individually quoted, * expands to all elements quoted as a whole. 
file_list=$( IFS=, ; echo "${csv_files[*]//XX/$iteration}" )
get_cmd="/usr/bin/s3cmd get -f s3://sp-ops-csv/{$file_list}.csv /tmp"
get_cmd+=";/usr/bin/s3cmd get -f s3://sp-ops-csv/$script_name subscriptions/management/commands"
if [ $dry_run ]; then
    echo -e ${get_cmd//;/'\n'}
else
    eval $get_cmd
fi 

if [ $morning ]; then 
    echo -e "\n[ Running morning script... ]"

    mgmtcmd="/usr/bin/time python manage.py bt_manual_recon_morning_script --input_csv=/tmp/subscriptions_${iteration}.csv \
             --sf_account_locations_csv=/tmp/locations_${iteration}.csv --sf_contacts_csv=/tmp/contacts_${iteration}.csv \
             --done_customers_csv=/tmp/done_customers_${iteration}.csv"
    uploadcmd="/usr/bin/s3cmd put ./bt_manual_recon_morning.csv s3://sp-ops-csv/"

    timecmd="/usr/bin/time ls"
    if [ $dry_run ]; then
	echo $mgmtcmd
	echo $uploadcmd
    else 
	rm -f ./bt_manual_recon_morning.csv
	echo $mgmtcmd
	$mgmtcmd || { echo -e "NO OUTPUT uploaded as script failed."; exit 1; }

	echo -e "\n[ Putting ./bt_manual_recon_morning.csv to bucket...]"
	echo $uploadcmd
	$uploadcmd
    fi 

else
    echo -e "\n[ Running evening script... ]"

    mgmtcmd="/usr/bin/time python manage.py bt_manual_recon_evening_script \
             --ctct_input_csv=/tmp/bt_manual_recon_morning_${iteration}_JM.csv \
             --done_customers_csv=/tmp/done_customers_${iteration}.csv"
    uploadcmd="/usr/bin/s3cmd put ./ctct_input_csv_copy.csv s3://sp-ops-csv/"
    uploadcmd+=";/usr/bin/s3cmd put /tmp/done_customers_${iteration}.csv s3://sp-ops-csv/done_customers_$((iteration+1)).csv"

    if [ $dry_run ]; then
	echo -e "\n...DRY_RUN mode"
	echo $mgmtcmd
	echo -e ${uploadcmd//;/'\n'}
    else 
	rm -f ./ctct_input_csv_copy.csv
	echo $mgmtcmd
	$mgmtcmd || { echo -e "NO OUTPUT uploaded as script failed."; exit 1; }

	echo -e "\n[ Putting ./ctct_input_csv_copy.csv and /tmp/done_customers_${iteration}.csv to bucket... ]"
	echo $uploadcmd
	$uploadcmd
    fi 

fi    


