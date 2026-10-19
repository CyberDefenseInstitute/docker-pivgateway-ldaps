#!/bin/bash
set -euo pipefail

new_database=0
# Initialize a new volume only. Existing LDAP databases/configuration are retained.
if [ ! -f /etc/ldap/slapd.d/cn=config.ldif ]; then
    debconf-set-selections <<CONFIG
slapd slapd/no_configuration boolean false
slapd slapd/domain string ${LDAP_DOMAIN:-example.com}
slapd shared/organization string ${LDAP_ORGANISATION:-Example Inc.}
slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD:?LDAP_ADMIN_PASSWORD is required}
slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/backend select MDB
slapd slapd/purge_database boolean false
slapd slapd/move_old_database boolean true
CONFIG
    dpkg-reconfigure -f noninteractive slapd
    new_database=1
fi
mkdir -p /run/slapd
chown -R openldap:openldap /run/slapd /var/lib/ldap /etc/ldap/slapd.d

if [ "$new_database" = 1 ] || [ "${LDAP_TLS:-false}" = true ]; then
    slapd -h ldapi:/// -u openldap -g openldap -d 0 &
    setup_pid=$!
    trap 'kill "$setup_pid" 2>/dev/null || true' EXIT
    for attempt in {1..30}; do
        if ldapwhoami -Q -Y EXTERNAL -H ldapi:/// >/dev/null 2>&1; then break; fi
        sleep 1
    done
    if [ "$new_database" = 1 ]; then
        shopt -s nullglob
        for configuration in /bootstrap-config/*.ldif; do
            ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f "$configuration"
        done
        ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<MEMBEROF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: memberof

dn: olcOverlay=memberof,olcDatabase={1}mdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcMemberOf
olcOverlay: memberof
olcMemberOfRefInt: TRUE
olcMemberOfGroupOC: ${LDAP_MEMBEROF_GROUP_OC:-groupOfNames}
olcMemberOfMemberAD: ${LDAP_MEMBEROF_MEMBER_AD:-member}
olcMemberOfMemberOfAD: memberOf
MEMBEROF
        base_dn=$(printf '%s' "$LDAP_DOMAIN" | sed 's/^/dc=/;s/\./,dc=/g')
        if [ "${LDAP_READONLY_USER:-false}" = true ]; then
            readonly_hash=$(slappasswd -s "${LDAP_READONLY_USER_PASSWORD:-readonly}")
            ldapadd -x -H ldapi:/// -D "cn=admin,$base_dn" -w "$LDAP_ADMIN_PASSWORD" <<READONLY
dn: cn=${LDAP_READONLY_USER_USERNAME:-readonly},$base_dn
objectClass: organizationalRole
objectClass: simpleSecurityObject
cn: ${LDAP_READONLY_USER_USERNAME:-readonly}
userPassword: $readonly_hash
READONLY
        fi
        shopt -s nullglob
        if [ "${LDAP_BOOTSTRAP:-true}" = true ]; then
            for fixture in /bootstrap/*.ldif; do
                ldapadd -x -H ldapi:/// \
                    -D "cn=admin,$base_dn" \
                    -w "$LDAP_ADMIN_PASSWORD" -f "$fixture"
            done
        fi
    fi
    if [ "${LDAP_TLS:-false}" = true ]; then
        cert_dir=${LDAP_TLS_CERT_DIR:-/certs}
        ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<TLS
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: $cert_dir/${LDAP_TLS_CA_CRT_FILENAME:-ca.crt}
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: $cert_dir/${LDAP_TLS_CRT_FILENAME:-ldap.server.example.com.crt}
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: $cert_dir/${LDAP_TLS_KEY_FILENAME:-ldap.server.example.com.key}
-
replace: olcTLSVerifyClient
olcTLSVerifyClient: ${LDAP_TLS_VERIFY_CLIENT:-never}
TLS
    fi
    kill "$setup_pid"
    wait "$setup_pid" || true
    trap - EXIT
fi
urls='ldap:/// ldapi:///'
if [ "${LDAP_TLS:-false}" = true ]; then urls="$urls ldaps:///"; fi
echo "LDAP initialization complete"
exec slapd -h "$urls" -u openldap -g openldap -d "${LDAP_LOG_LEVEL:-256}"
