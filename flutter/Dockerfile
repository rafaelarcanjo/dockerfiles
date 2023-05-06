# Código baseado no repositório: https://github.com/cirruslabs/docker-images-flutter/blob/master/sdk/Dockerfile
# Autor: Fedor Korotkov @fkorotkov
# Data: 2023-05-06

FROM ghcr.io/cirruslabs/android-sdk:33

LABEL org.opencontainers.image.source=https://github.com/cirruslabs/docker-images-flutter
USER root

ENV FLUTTER_HOME=/root/sdks/flutter \
    FLUTTER_VERSION=3.7.12
ENV FLUTTER_ROOT=$FLUTTER_HOME

ENV PATH ${PATH}:${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin

RUN git clone --depth 1 --branch 3.7.12 https://github.com/flutter/flutter.git ${FLUTTER_HOME}

RUN yes | flutter doctor --android-licenses \
    && flutter doctor \
    && chown -R root:root ${FLUTTER_HOME}

RUN apt-get update && apt-get install gettext -y && apt-get clean autoclean && apt-get autoremove --yes && rm -rf /var/lib/{apt,dpkg,cache,log}/
