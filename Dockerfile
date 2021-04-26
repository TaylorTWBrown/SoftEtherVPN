FROM alpine:latest as prep

LABEL maintainer="Tomohisa Kusano <siomiz@gmail.com>" \
      contributors="See CONTRIBUTORS file <https://github.com/siomiz/SoftEtherVPN/blob/master/CONTRIBUTORS>"

ENV BUILD_VERSION=master

RUN wget https://github.com/SoftEtherVPN/SoftEtherVPN/archive/master.tar.gz \
    && mkdir -p /usr/local/src \
    && tar -x -C /usr/local/src/ -f ${BUILD_VERSION}.tar.gz \
    && rm ${BUILD_VERSION}.tar.gz

FROM alpine:latest as build

COPY --from=prep /usr/local/src /usr/local/src

ENV LANG=en_US.UTF-8

RUN apk add -U build-base ncurses-dev openssl-dev readline-dev zip zlib-dev cmake libsodium-dev \
    && cd /usr/local/src/SoftEtherVPN-* \
    && ./configure \
    && make \
    && make install \
    && touch /usr/vpnserver/vpn_server.config \
    && zip -r9 /artifacts.zip /usr/vpn* /usr/bin/vpn*

FROM alpine:latest

COPY --from=build /artifacts.zip /

COPY copyables /

ENV LANG=en_US.UTF-8

RUN apk add -U --no-cache bash iptables openssl-dev \
    && chmod +x /entrypoint.sh /gencert.sh \
    && unzip -o /artifacts.zip -d / \
    && rm /artifacts.zip \
    && rm -rf /opt \
    && ln -s /usr/vpnserver /opt \
    && find /usr/bin/vpn* -type f ! -name vpnserver \
       -exec sh -c 'ln -s {} /opt/$(basename {})' \;

WORKDIR /usr/vpnserver/

VOLUME ["/usr/vpnserver/server_log/", "/usr/vpnserver/packet_log/", "/usr/vpnserver/security_log/"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 500/udp 4500/udp 1701/tcp 1194/udp 5555/tcp 443/tcp

CMD ["/usr/bin/vpnserver", "execsvc"]
