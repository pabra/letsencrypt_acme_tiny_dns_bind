ARG BASE_IMAGE=
FROM ${BASE_IMAGE}

ARG ACME_TINY_DNS_VERSION=v2.3
ARG DNSPYTHON_VERSION=2.1.0-r1
ARG REQUESTS_VERION=2.25.1-r4

VOLUME ["/keys", "/certs"]

RUN apk add --no-cache openssl python3 py3-dnspython=${DNSPYTHON_VERSION} py3-requests=${REQUESTS_VERION} bash \
    && wget https://projects.adorsaz.ch/adrien/acme-dns-tiny/raw/${ACME_TINY_DNS_VERSION}/acme_dns_tiny.py -O /usr/local/bin/acme_dns_tiny.py \
    && chmod +x /usr/local/bin/acme_dns_tiny.py

WORKDIR /tmp

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

CMD ["renew"]
