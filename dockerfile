FROM alpine:3.14.3 AS base

RUN apk add --no-cache \
    ca-certificates \
    iptables

RUN apk add --no-cache bash curl jq

RUN curl -LO https://get.helm.sh/helm-v3.2.1-linux-amd64.tar.gz
RUN tar -xvf helm-v3.2.1-linux-amd64.tar.gz
RUN cp linux-amd64/helm /bin/helm3

COPY *.sh /
RUN chmod +x *.sh
