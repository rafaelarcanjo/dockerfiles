FROM docker.io/alpine:3.15

ENV CURL_VERSION="7.81.0"

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache gcc make musl-dev openssl-dev libssh2-dev wget \
    && wget https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.xz \
    && tar xvfJ curl-${CURL_VERSION}.tar.xz \
    && cd curl-${CURL_VERSION} \
    && ./configure LIBS=-ldl \
        --with-libssh2 \
        --with-winssl \
        --disable-imap \
        --disable-imaps \
        --disable-pop3 \
        --disable-pop2s \
        --disable-rtsp \
        --disable-smb \
        --disable-smbs \
        --disable-smtp \
        --disable-smtps \
        --disable-telnet \
        --disable-gopher \
        --without-ssl \
    && make \
    && make install

FROM docker.io/alpine:3.15

RUN apk update --no-cache \
    && apk add --no-cache bash openssh git \
    && rm -f /usr/lib/libcurl.so.4

COPY "git-ftp.sh" "/usr/local/bin/git-ftp"
COPY --from=0 "/usr/local/lib/libcurl.so.4.7.0" "/usr/lib/"
COPY --from=0 "/usr/local/bin/curl" "/usr/bin/curl"
COPY --from=0 "/usr/lib/libssh2.so.1.0.1" "/usr/lib/"

RUN ln -s /usr/lib/libcurl.so.4.7.0 /usr/lib/libcurl.so.4 \
    && ln -s /usr/lib/libcurl.so.4 /usr/lib/libcurl.so \
    && ln -s /usr/lib/libssh2.so.1.0.1 /usr/lib/libssh2.so \
    && ln -s /usr/lib/libssh2.so.1.0.1 /usr/lib/libssh2.so.1 \
    && chmod +x usr/local/bin/git-ftp