# Seeds the demo on first start, then puts its data back every interval.
FROM postgres:18-alpine
RUN apk add --no-cache bash curl jq docker-cli docker-cli-compose redis tzdata
COPY *.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh
ENTRYPOINT ["/usr/local/bin/main.sh"]
