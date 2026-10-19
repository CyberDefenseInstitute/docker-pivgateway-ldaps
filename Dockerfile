FROM ubuntu:26.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update && apt-get install -y --no-install-recommends devscripts libssl-dev \
    && apt-get build-dep -y openldap
WORKDIR /build
RUN apt-get source openldap && cd openldap-* \
    && sed -i 's/\(--with-tls=\).*/\1openssl/' debian/configure.options \
    && DEB_BUILD_OPTIONS=nocheck debuild -us -uc -b

FROM ubuntu:26.04
ENV DEBIAN_FRONTEND=noninteractive LDAP_DOMAIN=example.com LDAP_ADMIN_PASSWORD=admin
RUN apt-get update && apt-get install -y --no-install-recommends \
    slapd ldap-utils ca-certificates openssl netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /build/libldap*.deb /build/slapd_*.deb /build/ldap-utils_*.deb /tmp/ldap/
RUN dpkg -i /tmp/ldap/*.deb && rm -rf /tmp/ldap \
    && rm -rf /etc/ldap/slapd.d/* /var/lib/ldap/*
COPY ldap-entrypoint.sh /usr/local/bin/
EXPOSE 389 636
ENTRYPOINT ["ldap-entrypoint.sh"]
ENV LDAP_TLS=true LDAP_TLS_CRT_FILENAME=ldap.crt LDAP_TLS_KEY_FILENAME=ldap.key \
    LDAP_READONLY_USER=true LDAP_READONLY_USER_USERNAME=readonly LDAP_READONLY_USER_PASSWORD=readonly
COPY certs /certs
COPY bootstrap/ldif/example.ldif /bootstrap/50-example.ldif
