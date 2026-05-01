FROM alpine

RUN apk add bash

COPY ./update-config.sh /update-config.sh
RUN chmod +x /update-config.sh

CMD [ "/update-config.sh" ]