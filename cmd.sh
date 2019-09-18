#!/bin/bash

USER="${USER:-root}"

mysqldump \
    -h 127.0.0.1 -P 3306 -u ${USER} \
    --databases ${DATABASES}  \
    --hex-blob  --skip-triggers  --master-data=1  \
    --order-by-primary --no-autocommit \
    --default-character-set=utf8mb4 \
    --single-transaction --set-gtid-purged=on "-p${SOURCE_PASSWORD}" | gzip | \
    gsutil cp - gs://${BUCKET}/dump.sql.gz

gcloud beta sql instances create \
  ${REPRESENTATION_NAME} \
  --region=${REGION} \
  --database-version=${DATABASE_VERSION} \
  --source-ip-address=${SOURCE_IP} \
  --source-port=${SOURCE_PORT}

gcloud beta sql instances create ${REPLICA_NAME} \
    --master-instance-name=${REPRESENTATION_NAME} \
    --master-username=${REPLICA_USER} \
    --master-password=${REPLICA_PASSWORD} \
    --master-dump-file-path=gs://${BUCKET}/dump.sql.gz \
    --tier=${MACHINE_TYPE} \
    --storage-size=${DISK_SIZE}

IP_ADDRESS=''
until [[! -z IP_ADDRESS ]]; do
  IP_ADDRESS=$(gcloud sql instances describe ${REPLICA_NAME} --format="flattened(ipAddresses)" | sed '3q;d' | grep -oP '(?<=: )[^ ]*')
done

echo "Outgoing IP: ${IP_ADDRESS}"
gcloud sql instances patch ${SOURCE_DATABASE_NAME} --authorized-networks=$IP_ADDRESS
