FROM alpine:3.13.5

ARG ACME_TINY_DNS_VERSION=1d7c9423653b3921df207658c34fdacb2913ec1a \
    DNSPYTHON_VERSION=2.1.0-r0 \
    REQUESTS_VERION=2.25.1-r1

VOLUME ["/keys", "/certs"]

RUN apk add --no-cache openssl python3 py3-dnspython=${DNSPYTHON_VERSION} py3-requests=${REQUESTS_VERION} bash \
    && wget https://projects.adorsaz.ch/adrien/acme-dns-tiny/raw/${ACME_TINY_DNS_VERSION}/acme_dns_tiny.py -O /usr/local/bin/acme_dns_tiny.py \
    && chmod +x /usr/local/bin/acme_dns_tiny.py

WORKDIR /tmp

ADD entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

CMD ["renew"]
