FROM alpine

RUN apk -U add bash jq yq findutils grep

COPY ./update-config.sh /update-config.sh
RUN chmod +x /update-config.sh

CMD [ "/update-config.sh" ]