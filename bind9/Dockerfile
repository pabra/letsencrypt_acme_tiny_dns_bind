ARG BASE_IMAGE=
FROM ${BASE_IMAGE}

ARG BIND_VERSION=9.18.19-r1

RUN apk add --no-cache bind=${BIND_VERSION} bind-tools=${BIND_VERSION}

VOLUME ["/var/bind/keys"]

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

CMD ["named", "-c", "/etc/bind/named.conf", "-g", "-u", "named"]
