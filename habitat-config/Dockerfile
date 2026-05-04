FROM alpine

RUN apk -U add bash jq yq findutils grep

RUN mkdir -p /habitat-config

COPY ./update-config.sh /habitat-config/update-config.sh
RUN chmod +x /habitat-config/update-config.sh

COPY ./consumer.sh /habitat-config/consumer.sh
RUN chmod +x /habitat-config/consumer.sh

WORKDIR /habitat-config

CMD [ "/habitat-config/update-config.sh" ]