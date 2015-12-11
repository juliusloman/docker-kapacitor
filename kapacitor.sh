#!/bin/sh

perl /usr/local/bin/ModifyKapacitorConfig.pl /etc/kapacitor/kapacitor.conf /var/lib/kapacitor/kapacitor.conf

exec kapacitord -config /var/lib/kapacitor/kapacitor.conf -hostname $HOSTNAME
