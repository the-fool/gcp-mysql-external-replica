#!/bin/bash

USER="${USER:-root}"

if [ -z "$DATABASES" ]; then 
	echo "DATABASES must be set: db1,db2"
fi

if [ -z "$SOURCE_NAME" ]; then 
	echo "SOURCE_NAME must be set: project:db"
fi


if [ -z "$BUCKET" ]; then 
	echo "Bucket must be set: my-bucket"
fi

source /root/google-cloud-sdk/path.bash.inc

echo "Starting Cloud SQL Proxy"

# /cloud_sql_proxy -instances=${SOURCE_NAME}=tcp:3306 -credential_file=/creds/creds.json &
/cloud_sql_proxy -instances=${SOURCE_NAME}=tcp:3306 &

sleep 2
COUNTER=0
until mysql -u root -h 127.0.0.1 "-p${SOURCE_PASSWORD}" -e '\q'
do
  if [ $COUNTER -gt 4 ]; then
    echo "Unable to connect SQL proxy."
    exit 1
  fi
  COUNTER=$(( $counter + 1 ))
  echo "Waiting for connection . . . "
  sleep 2
done


exec "$@"
