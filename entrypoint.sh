#!/bin/bash

USER="${USER:-root}"

source /root/google-cloud-sdk/path.bash.inc

SOURCE_NAME=${SOURCE_PROJECT}:${SOURCE_REGION}:${SOURCE_DATABASE_NAME}
echo "Starting Cloud SQL Proxy connection to ${SOURCE_NAME}"

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
  COUNTER=$(( $COUNTER + 1 ))
  echo "Waiting for connection . . . "
  sleep 2
done


exec "$@"
