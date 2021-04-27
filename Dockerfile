FROM alpine:latest as prep

LABEL maintainer="Tomohisa Kusano <siomiz@gmail.com>" \
      contributors="See CONTRIBUTORS file <https://github.com/siomiz/SoftEtherVPN/blob/master/CONTRIBUTORS>"

ENV BUILD_VERSION=master \
    CPU_FEATURES_VERSION=master \
    CPU_FEATURES_VERIFY=4AEE18F83AFDEB23

RUN wget https://github.com/SoftEtherVPN/SoftEtherVPN/archive/master.tar.gz \
    && mkdir -p /usr/local/src \
    && tar -x -C /usr/local/src/ -f ${BUILD_VERSION}.tar.gz \
    && rm ${BUILD_VERSION}.tar.gz

RUN apk add git gnupg \
    && gpg --keyserver hkp://keys.gnupg.net --recv-keys ${CPU_FEATURES_VERIFY} \
    && git clone https://github.com/google/cpu_features.git /usr/local/src/SoftEtherVPN-${BUILD_VERSION}/src/Mayaqua/3rdparty/cpu_features \
    && cd /usr/local/src/SoftEtherVPN-${BUILD_VERSION}/src/Mayaqua/3rdparty/cpu_features \
    && git checkout ${CPU_FEATURES_VERSION} \
    && cd -

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
