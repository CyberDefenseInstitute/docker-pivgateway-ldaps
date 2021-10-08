# ldap docker image for PIV Gateway 

本レポジトリに`検証目的`のためのopenldap docker imageを用意しています。 

注意: 商用利用ではお客様にて準備した認証局、LDAP環境を準備ください。

## LDAPの概要

PIV Gatewayの検証目的のためにldap環境をdockerを利用して構築することが可能です。
なおLDAPは下記レポジトリのExample CAを利用したサーバ証明書を利用しています

https://github.com/CyberDefenseInstitute/pivgateway-sample-ca

ldap docker imageは[osixia/openldap:1.5.0](https://github.com/osixia/docker-openldap)を利用し検証に必要なldapオブジェクトを登録しています。[osixia/openldap:1.5.0](https://github.com/osixia/docker-openldap)に関する詳細につていは公式ページを参照ください。

### 利用方法

本ディレクトリ内の`bootstrap/ldif/example.ldif`のオブジェクトをldapサーバに登録しています。

事前に登録済みのオブジェクトの詳細は`bootstrap/ldif/example.ldif`を確認ください。

また本ディレクトリ内の`environment/ldif/env.startup.yaml`でサーバ初期設定を行っています。

`make`もしくは`docker build -t docker-pivgateway-ldaps .`を実行その後 `./run.sh`を実行するとサーバが起動します。

pivgateway serverからクエリーを行う場合には、"cn=admin,dc=example,dc=com"をbinding accountとして指定しpasswordを`admin`とすることで利用可能です。

### PIV Gatewayの検証

例) 
piv gateway serverの設定を以下の様に行う

```
#LDAP user settings
LDAP {
    #LDAP server full URI (starting with ldap://) (required) schema "ldap:// is starttls, "ldaps" is TLS 
    server = "ldap://ldap.server.example.com" 
    #bind DN (required)
    bind-dn = "cn=admin,dc=example,dc=com"
    #authentication password (required)
    bind-password = "admin"
    #LDAP search base (required)
    search-base = "dc=example,dc=com"
    #Query settings
    #The following settings will be combined to generate the query used to authenticate user access
    #to a specific door.  Specified fields can be replaced with data from user and reader certificates
    #in order to create the correct query. See the wiki page "ldap_query" for details.
    #
    #***** The strings MUST be enclosed in single quotes (') for field substitution to work*****
    #
    memberof-filter = '(memberof=cn=${PIVREADER_X509_CN},ou=groups,dc=example,dc=com)'
    user-filter = '(|(cn=${USER_X509_CN})(mail=${USER_X509_SAN_RFC822}))'
    user-objects-filter = '(objectClass=inetOrgPerson)'
}
```

カードリーダにサンプルの[証明書](https://github.com/CyberDefenseInstitute/pivgateway-sample-ca/blob/main/room1.crt)を設定し、Yubikey 5 NFCにサンプルの[証明書](https://github.com/CyberDefenseInstitute/pivgateway-sample-ca/blob/main/Robert_Smith.pfx)で解錠要求を行った場合


memberof-filter条件は `(memberof=cn=room1,ou=groups,dc=example,dc=com)`となり
user-filter条件は`(&(|(cn=Robert Smith)(mail=rsmith@example.com))`となり
user-objects-filter条件は`(objectClass=inetOrgPerson)`となります。

したがって検索条件は`(&(|(cn=Robert Smith)(mail=rsmith@example.com))(memberof=cn=room1,ou=groups,dc=example,dc=com)(objectClass=inetOrgPerson))`となります。

従って以下のクエリがpiv gateway serverから行われ認可権限の確認が行われることになります。

```
$ ldapsearch -x -D "cn=admin,dc=example,dc=com" -W -b "dc=example,dc=com" '(&(|(cn=Robert Smith)(mail=rsmith@example.com))(memberof=cn=room1,ou=groups,dc=example,dc=com)(objectClass=inetOrgPerson))'

Enter LDAP Password:
# extended LDIF
#
# LDAPv3
# base <dc=example,dc=com> with scope subtree
# filter: (&(|(cn=Robert Smith)(mail=rsmith@example.com))(memberof=cn=room1,ou=groups,dc=example,dc=com)(objectClass=inetOrgPerson))
# requesting: ALL
#

# Robert Smith, people, example.com
dn: cn=Robert Smith,ou=people,dc=example,dc=com
objectClass: inetOrgPerson
cn: Robert Smith
cn: Robert J Smith
cn: bob  smith
sn: smith
uid: rjsmith
userPassword:: ckpzbWl0SA==
carLicense: HISCAR 123
homePhone: 555-111-2222
mail: r.smith@example.com
mail: rsmith@example.com
mail: bob.smith@example.com
description: swell guy
ou: Human Resources

# search result
search: 2
result: 0 Success

# numResponses: 2
# numEntries: 1
root@ldap:/# exit
```

## 認証局

- CN = Example CA

ディレクトリ cert 内にca.crt 公開鍵証明書がが保存されており、サーバが信頼する証明書として利用します。

証明書の有効期限は2041年9月22日

## サーバ証明書

### LDAP向けサーバ

- CN = ldap.server.example.com
- SAN = DNS:ldap.server.example.com
- X509v3 Extended Key Usage: TLS Web Server Authentication

ディレクトリ cert 内にldap.crt 公開鍵証明書、ldap.key 秘密鍵が保存されており、ldapのサーバ証明書として利用します。

なお証明書の有効期限は2031年9月22日となっています。
