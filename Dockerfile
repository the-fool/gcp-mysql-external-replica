FROM mysql:5.7

RUN apt-get update \
	&& apt-get install -y wget \
	&& apt-get install -y curl \
	&& apt-get install -y python

# install Cloud SQL Proxy
RUN wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /cloud_sql_proxy \
	&& chmod +x /cloud_sql_proxy

# install GCP SDK
RUN export CLOUDSDK_CORE_DISABLE_PROMPTS=1
RUN curl https://sdk.cloud.google.com | bash
RUN /bin/bash -c "source /root/google-cloud-sdk/path.bash.inc"
RUN /root/google-cloud-sdk/bin/gcloud components install beta 

ADD entrypoint.sh /entrypoint.sh
ADD script.sql /script.sql
ADD cmd.sh /cmd.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/cmd.sh"]
