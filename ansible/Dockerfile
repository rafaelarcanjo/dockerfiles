FROM python:3.9-alpine

ENV VERSION=2.10.7

LABEL org.opencontainers.image.authors="rafael@libre.tec.br"

RUN apk add --no-cache openssh \
    && pip install ansible==${VERSION}