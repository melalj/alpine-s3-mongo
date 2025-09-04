FROM alpine:edge
RUN apk update && apk add --no-cache \
    bash \
    python3 \
    py3-pip \
    py3-setuptools \
    mongodb-tools \
    && pip3 install --no-cache-dir --break-system-packages awscli
COPY ./backup.sh /backup.sh
COPY ./restore.sh /restore.sh
COPY ./thin.sh /thin.sh
COPY ./list-versions.sh /list-versions.sh
