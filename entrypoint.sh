#!/bin/bash

USER="${USER:-root}"

source /root/google-cloud-sdk/path.bash.inc

SOURCE_NAME=${SOURCE_PROJECT}:${SOURCE_REGION}:${SOURCE_DATABASE_NAME}
echo "Starting Cloud SQL Proxy for: ${SOURCE_NAME}"

/cloud_sql_proxy -instances=${SOURCE_NAME}=tcp:3306 >/dev/null 2>&1 &

# Attempt connection
COUNTER=0
until mysql -u root -h 127.0.0.1 "-p${SOURCE_PASSWORD}" -e '\q' >/dev/null 2>&1; do
  if [ $COUNTER -gt 4 ]; then
    echo "Unable to connect SQL proxy."
    exit 1
  fi
  sleep 2
  COUNTER=$(( $COUNTER + 1 ))
  echo "Waiting for proxy to connect . . . "
done

echo "Proxy connected and listening at 127.0.0.1:3306"

exec "$@"
