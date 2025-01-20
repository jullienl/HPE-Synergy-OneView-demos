#!/bin/bash

# OneView Synergy Appliance credentials
. oneview_config.sh

# Create session
ID=$(curl -s --location --request POST 'https://'${ONEVIEWIP}'/rest/login-sessions' \
--header 'X-API-Version: 800' \
--header 'Content-Type: application/json' \
--insecure \
--data-raw '{
"authLoginDomain":"Local",
"password":"'${ONEVIEWPASSWORD}'",
"userName":"'${ONEVIEWUSER}'"
}')

auth=$(echo $ID | jq -r .sessionID)
#echo $auth

if [ $auth != "null" ]; then 

	# Create the backup
	backuptask=$(curl -s --location -D - -o /dev/null \
	--request POST 'https://'${ONEVIEWIP}'/rest/backups' \
	--header 'X-API-Version: 2200' \
	--insecure \
	--header "Auth: $auth" )

	# Get task URL
	tasklocation=$(echo "$backuptask" | grep Location | awk '{ print substr ($0, 11 ) }')
	url=${tasklocation%$'\r'}
	#echo $url

	taskresult=""
	# Get task result
	until [ "$taskresult" = "Completed" ]; do
		taskresult=$( (curl -s --location \
		--request GET \
		--url $url \
		--insecure \
		--header 'X-API-Version: 2200' \
		--header "Auth: $auth") | jq -r ".taskState")
		sleep 5
		#echo $taskresult
		
	done
	
	echo "OneView backup completed!"

else
	echo "Error! Cannot connect to OneView!"

fi