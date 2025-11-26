FROM alpine:latest

RUN apk add --no-cache net-snmp-tools bash

COPY send_trap.sh /usr/local/bin/send_trap.sh
RUN chmod +x /usr/local/bin/send_trap.sh

CMD ["/usr/local/bin/send_trap.sh"]
