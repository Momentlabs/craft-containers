FROM logstash:latest

MAINTAINER David Rivas david@momentlabs.io

COPY artifacts/logstash.conf /logstash.conf

CMD ["-f", "/logstash.conf", "--log.level", "trace"]
