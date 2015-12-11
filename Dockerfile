FROM debian:latest
MAINTAINER Julius Loman <lomo@kyberia.net>

ADD ModifyKapacitorConfig.pl kapacitor.sh /usr/local/bin/

RUN apt-get update && apt-get -y install curl perl libregexp-common-perl && apt-get clean && \
 curl https://s3.amazonaws.com/influxdb/kapacitor_0.2.0-1_amd64.deb -o kapacitor.deb && \
 dpkg -i kapacitor.deb && \
 rm kapacitor.deb && \
 chmod +x /usr/local/bin/ModifyKapacitorConfig.pl /usr/local/bin/kapacitor.sh

USER kapacitor

CMD /usr/local/bin/kapacitor.sh
