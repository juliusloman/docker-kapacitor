# Kapacitor

Dockerfile of Influxdb's kapacitor (https://influxdb.com/docs/kapacitor/v0.1/introduction/index.html).

## Usage

Either map your kapacitor.conf to _/etc/kapacitor/kapacitor.conf_ using volume
mapping or you can substitute configuration properties using
KAPACITOR\_KEY=value. If KEY is formatted as SECTION\_KEY (environment variable
is KAPACITOR\_SECTION\_KEY) then value for key is modified/added in section
named SECTION.


For example:

	docker run -e KAPACITOR_influxdb_urls='["http://influxdb:8086"]' lomo/kapacitor

Don't forget the kapacitor's hostname must be resolvable from InfluxDB host. If you need to override hostname in kapacitor:
	
	docker run -e KAPACITOR_influxdb_urls='["http://influxdb:8086"]' -e HOSTNAME=kapacitor lomo/kapacitor

