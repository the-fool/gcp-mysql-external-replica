#!/bin/bash

USER="${USER:-root}"

mysqldump \
  -h 127.0.0.1 -P 3306 -u ${USER} \
  --databases ${DATABASES}  \
  --hex-blob  --skip-triggers  --master-data=1  \
  --order-by-primary --no-autocommit \
  --default-character-set=utf8mb4 \
  --single-transaction --set-gtid-purged=on "-p${SOURCE_PASSWORD}" \
  | gzip \
  | gsutil cp - gs://${BUCKET}/dump.sql.gz

gcloud beta sql instances create \
  ${REPRESENTATION_NAME} \
  --project=${REPLICA_PROJECT} \
  --region=${REGION} \
  --database-version=${DATABASE_VERSION} \
  --source-ip-address=${SOURCE_IP} \
  --source-port=${SOURCE_PORT}

echo "Creating slave instance.  This will take a minute."

gcloud beta sql instances create ${REPLICA_NAME} \
  --project=${REPLICA_PROJECT} \
  --master-instance-name=${REPRESENTATION_NAME} \
  --master-username=${REPLICA_USER} \
  --master-password=${REPLICA_PASSWORD} \
  --master-dump-file-path=gs://${BUCKET}/dump.sql.gz \
  --tier=${MACHINE_TYPE} \
  --storage-size=${DISK_SIZE} &

echo "Slave instance creating.  Waiting for outgoing IP address"

IP_ADDRESS=''
COUNTER=0
until [[ -n "$IP_ADDRESS" ]]; do
  if [ $COUNTER -gt 30 ]; then
    echo "Unable to create database"
    exit 1
  fi
  sleep 5
  COUNTER=$(( $COUNTER + 1 ))
  IP_ADDRESS=$(gcloud sql instances describe ${REPLICA_NAME} --format="flattened(ipAddresses)" \
    | sed '3q;d' \
    | grep -oP '(?<=: )[^ ]*')
done

echo "Outgoing IP: ${IP_ADDRESS}"
ORIGINAL_AUTHORIZED_IPS=$(gcloud sql instances describe ${SOURCE_DATABASE_NAME} --format="csv(settings.ipConfiguration.authorizedNetworks[].value)" \
  | tail -n 1 \
  | sed 's/;/,/g')
echo "Original source authorized IPS: $ORIGINAL_AUTHORIZED_IPS"

NEW_IPS=$ORIGINAL_AUTHORIZED_IPS,$IP_ADDRESS

echo "Adding slave IP to authorized networks for source database"

gcloud sql instances patch ${SOURCE_DATABASE_NAME} --authorized-networks=$NEW_IPS --quiet

echo "Waiting for operation to complete.  This may take 10 minutes."
COUNTER=0
until [[ RUNNABLE == $(gcloud sql instances describe ${REPLICA_NAME} --format="value(state)") ]]; do
  if [[ $COUNTER -gt 30 ]]; then
    echo "Timed out creating instance"
    exit 1
  fi
  COUNTER=$(( $COUNTER + 1 ))
  sleep 5
done
