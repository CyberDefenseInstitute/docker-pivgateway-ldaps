# Pull base image.
FROM osixia/openldap:1.5.0

LABEL Description="ldap docker image for PIV Gateway" Vendor="Cyberdefense Institute" Version="1.0"
ADD certs /container/service/slapd/assets/certs
ADD bootstrap /container/service/slapd/assets/config/bootstrap

