FROM alpine:3.19

ADD named.conf /etc/bind/

RUN apk add --no-cache bind && \
    rm -rf /var/cache/apk/*
    
EXPOSE 53/udp

ENTRYPOINT ["/usr/sbin/named", "-f", "-g"]