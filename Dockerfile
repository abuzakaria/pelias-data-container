FROM elasticsearch:1.7
MAINTAINER Reittiopas version: 0.1

# Finalize elasticsearch installation

ADD config/elasticsearch.yml /usr/share/elasticsearch/config/

RUN mkdir -p /var/lib/elasticsearch/pelias_data \
  && chown -R elasticsearch:elasticsearch /var/lib/elasticsearch/pelias_data

ENV ES_HEAP_SIZE 4g

# Install dependencies for importers

RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends git unzip python python-pip python-dev build-essential gdal-bin rlwrap \
  && rm -rf /var/lib/apt/lists/*

RUN curl https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.9-1nodesource1~jessie1_amd64.deb > node.deb \
 && dpkg -i node.deb \
 && rm node.deb

# Auxiliary folders
RUN rm -rf /mnt \
  & mkdir -p /mnt/data/openstreetmap \
  & mkdir -p /tmp/openstreetmap \
  & mkdir -p /mnt/data/openaddresses \
  & mkdir -p /mnt/data/quattroshapes

# Download quattroshapes data (only higher levels will be used)
WORKDIR /mnt/data/quattroshapes
RUN curl -sS -O http://quattroshapes.mapzen.com/quattroshapes/quattroshapes-simplified.tar.gz \
  && tar zxvf quattroshapes-simplified.tar.gz && rm -f quattroshapes-simplified.tar.gz \
  && SHAPE_ENCODING="ISO-8859-1" ogr2ogr qs_adm0.shp simplified/qs_adm0.shp -lco ENCODING=UTF-8 \
  && SHAPE_ENCODING="ISO-8859-1" ogr2ogr qs_adm1.shp simplified/qs_adm1.shp -lco ENCODING=UTF-8 \
  && SHAPE_ENCODING="ISO-8859-1" ogr2ogr qs_adm2.shp simplified/qs_adm2.shp -lco ENCODING=UTF-8 \
  && SHAPE_ENCODING="ISO-8859-1" ogr2ogr qs_localadmin.shp simplified/qs_localadmin.shp -lco ENCODING=UTF-8 \
  && rm -rf simplified


# Download OpenStreetMap
WORKDIR /mnt/data/openstreetmap
RUN curl -sS -O http://download.bbbike.org/osm/planet/planet-latest.osm.pbf

# Download openaddress
WORKDIR /mnt/data/openaddresses
RUN curl -sS -O http://s3.amazonaws.com/data.openaddresses.io/openaddr-collected-global.zip \
  && unzip -o openaddr-collected-global.zip \
  && rm openaddr-collected-global.zip 


WORKDIR /root

# Copying pelias config file
ADD pelias.json pelias.json

# Add elastisearch-head plugin for browsing ElasticSearch data
RUN chmod +wx /usr/share/elasticsearch/plugins/
RUN /usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head

RUN gosu elasticsearch elasticsearch -d \
  && npm install -g pelias-cli \
  && sleep 30 \
  && pelias schema#production create_index \
  && pelias openaddresses#production import --admin-values \
  && pelias openstreetmap#production import

RUN chmod -R a+rwX /var/lib/elasticsearch/ \
  && chown -R 9999:9999 /var/lib/elasticsearch/

ENV ES_HEAP_SIZE 1g

ENTRYPOINT ["elasticsearch"]

USER 9999
