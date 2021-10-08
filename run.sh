#!/bin/bash

docker run --rm --hostname ldap.server.example.com -p 389:389 -p 636:636 --name ldap --env LDAP_DOMAIN="example.com" docker-pivgateway-ldaps --loglevel debug
