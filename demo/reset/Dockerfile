# Seeds the demo on first start, then puts its data back every interval. It
# also owns the lab (lab.yml): brings it up and rebuilds it at every reset.
FROM postgres:18-alpine
RUN apk add --no-cache bash curl jq docker-cli docker-cli-compose redis tzdata
COPY *.sh /usr/local/bin/
COPY lab.yml /etc/morche-demo/lab.yml
RUN chmod +x /usr/local/bin/*.sh
ENTRYPOINT ["/usr/local/bin/main.sh"]
