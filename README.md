step -1:
once the containers are created, we need to add the init.ldif to the ldap server
docker cp ldap/ldif/init.ldif ldap:/tmp/init.ldif

step -2:
now import the ldif configurations on to the ldap server.
MSYS_NO_PATHCONV=1 docker exec ldap ldapadd -x \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=example,dc=com" \
  -w admin \
  -f /tmp/init.ldif

now alice and bob can access guacamole with respective creds. 
step 3: 
