from alpine:3.3

RUN apk add --no-cache rsyslog \
  && rm -rf /var/cache/apk/*

EXPOSE 514 514/udp

COPY ./rsyslog.conf /etc/rsyslog.conf

ENTRYPOINT ["rsyslogd", "-nd"]