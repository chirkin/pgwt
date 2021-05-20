FROM openresty/openresty:bionic

RUN apt-get install -y --no-install-recommends curl ca-certificates gnupg
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get -y install postgresql-client-13

RUN luarocks install pgmoon
RUN luarocks install luafilesystem
RUN luarocks install net-url

ADD docker/pgwt-openresty/docker-entrypoint.sh /

COPY docker/pgwt-openresty/10-envsubst-on-templates.sh /docker-entrypoint.d/

COPY docker/pgwt-openresty/conf/*.template /etc/nginx/templates/
COPY src/lua/*.lua /usr/local/openresty/nginx/
#COPY src/lua/lualib/*.lua /usr/local/openresty/lualib/

ENTRYPOINT ["/docker-entrypoint.sh"]
RUN chmod +x /docker-entrypoint.sh
RUN chmod -R +x /docker-entrypoint.d/*

# Use SIGQUIT instead of default SIGTERM to cleanly drain requests
# See https://github.com/openresty/docker-openresty/blob/master/README.md#tips--pitfalls
STOPSIGNAL SIGQUIT

EXPOSE 8080

CMD ["openresty", "-g", "daemon off;"]

# Default nginx environments
ENV NGX_WORKER_PROCESSES=1 \
		NGX_WORKER_CONNECTIONS=1024 \
		PGWT_CONN_PORT=5432
