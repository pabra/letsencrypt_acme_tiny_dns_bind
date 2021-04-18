FROM alpine:3.13.5

ARG BIND_VERSION=9.16.11-r1

RUN apk add --no-cache bind=${BIND_VERSION} bind-tools=${BIND_VERSION}

VOLUME ["/var/bind/keys"]

ADD entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

CMD ["named", "-c", "/etc/bind/named.conf", "-g", "-u", "named"]
