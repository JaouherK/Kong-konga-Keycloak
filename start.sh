#!/bin/bash

HOST_IP="localhost"

echo "Important: Make sure jq is installed in the system"

echo "Checking Konga admin user"
KONGA_TOKEN=$(curl -s POST http://${HOST_IP}:1337/login --header 'Content-Type: application/json' --header 'Accept: application/json' --data '{"identifier": "admin", "password": "00000000"}' | jq -r '.token')
if [[ $(echo ${KONGA_TOKEN}) != null ]]; then
    echo -e "\e[1;31m User already existing! canceling Konga configuration. \e[0m\n"
else
echo "Creating Konga admin user"
curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "username=admin" -d "email=admin%40test.com" -d "password=00000000" -d "password_confirmation=00000000" http://${HOST_IP}:1337/register

echo "Authentication to Konga"
KONGA_TOKEN=$(curl -s POST http://${HOST_IP}:1337/login --header 'Content-Type: application/json' --header 'Accept: application/json' --data '{"identifier": "admin", "password": "00000000"}' | jq -r '.token')

echo ${KONGA_TOKEN}

echo "Creating kong node"

KONG_NODE=$(curl -s POST http://${HOST_IP}:1337/api/kongnode \
--header "Authorization: Bearer ${KONGA_TOKEN}" \
--header 'Content-Type: application/json' \
--data-raw '[
  {
    "type": "default",
    "jwt_algorithm": "HS256",
    "name": "kong",
    "kong_admin_url": "http://kong:8001",
    "kong_api_key": "",
    "kong_version": "2.0.0",
    "health_checks": false,
    "active": true
  }
]')

echo ${KONG_NODE} | jq .
KONG_NODE_ID=$(echo ${KONG_NODE} | jq '.[0].id')

curl -s GET http://${HOST_IP}:1337/kong?connection_id=${KONG_NODE} \
--header "Authorization: Bearer ${KONGA_TOKEN}" \
--header 'Accept: application/json'

curl -s POST http://${HOST_IP}:1337/logout
echo -e "\e[1;31m Finalised Konga configuration. \e[0m\n"
fi

hash jq 2>/dev/null || { echo >&2 "I require foo but it's not installed.  Aborting."; exit 1; }
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "Making sure that kong-oidc is installed this should return true"
OIDC=$(curl -s http://${HOST_IP}:8001 | jq .plugins.available_on_server.oidc)
if [[ $(echo ${OIDC}) != 'true' ]]; then
    echo -e "\e[1;31m Please verify configuration. Can't find OIDC plugin \e[0m"
	exit 0
fi
echo ${OIDC}
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "To test the system, we will use MockBin.org"
echo -n "      Please provide mock service name: "
read MOCK
SERVICE=$(curl -s -X POST http://${HOST_IP}:8001/services \
    -d name=${MOCK} \
    -d url=http://mockbin.org/request \
    | jq .)

printf "\nMockBin.org response:\n"
echo ${SERVICE} | jq .
SERVICE_ID=$(echo ${SERVICE}  | jq -r '.id')
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "Creating the route mapped to service $MOCK (ID: $SERVICE_ID)"
echo -n "      Please choose the relative route through kong: /"
read ROUTE
curl -s -X POST http://${HOST_IP}:8001/services/${SERVICE_ID}/routes -d "paths[]=/$ROUTE" \
    | jq .
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -


echo "Sending request to /$ROUTE to make sure it is reachable"
curl -v http://${HOST_IP}:8000/${ROUTE} |jq .
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo -e "\e[1;31m Mock service and associated routes configured successfully. \e[0m\n"

echo "Authenticate admin cli to KeyCloak"
ADMIN_TKN=$(curl -s POST http://${HOST_IP}:8180/auth/realms/master/protocol/openid-connect/token \
 -H "Content-Type: application/x-www-form-urlencoded" \
 -d "username=admin" \
 -d 'password=admin' \
 -d 'grant_type=password' \
 -d 'client_id=admin-cli' | jq -r '.access_token')

printf "\nAdmin token:  ${ADMIN_TKN}\n"

printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -


echo "Fetching Existing realms: "
REALMS=$(curl -s GET http://${HOST_IP}:8180/auth/admin/realms \
-H "Accept: application/json" \
-H "Authorization: Bearer $ADMIN_TKN")

printf "\nList of existing realms: \n"
echo ${REALMS} | jq '.[] .realm'
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "Creating new realm"
echo -n "      Please provide realm name to create: "
read REALM_NAME
curl -s POST http://${HOST_IP}:8180/auth/admin/realms \
  -H "Authorization: Bearer $ADMIN_TKN" \
  -H "Content-Type: application/json" \
  --data '{"realm": "'${REALM_NAME}'","displayName": "'${REALM_NAME}'","enabled": true}'
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "Creating new user: test@example.com/test"
curl -s POST http://${HOST_IP}:8180/auth/admin/realms/${REALM_NAME}/users \
  -H "Authorization: Bearer $ADMIN_TKN" \
  -H "Content-Type: application/json" \
   -d @data/test_user.json | jq .

echo "Displaying user info"
curl -s GET http://${HOST_IP}:8180/auth/admin/realms/${REALM_NAME}/users?username=test \
-H "Accept: application/json" \
-H "Authorization: Bearer $ADMIN_TKN" | jq '.[0]'
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -


echo -n "Kong client Secret: "
KONG_SECRET=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
echo ${KONG_SECRET}

echo "Creating Kong client"
curl -s POST http://${HOST_IP}:8180/auth/admin/realms/${REALM_NAME}/clients \
  -H "Authorization: Bearer $ADMIN_TKN" \
  -H "Content-Type: application/json" \
  --data '{"clientId": "kong","name": "kong","enabled": true,"protocol": "openid-connect","rootUrl": "http://'${HOST_IP}':8000","clientAuthenticatorType": "client-secret","publicClient": false,"directAccessGrantsEnabled": true,"adminUrl": "","secret": "'${KONG_SECRET}'","redirectUris": ["*"]}' | jq .


KONG_CLIENT=$(curl -s GET http://${HOST_IP}:8180/auth/admin/realms/${REALM_NAME}/clients?clientId=kong \
-H "Accept: application/json" \
-H "Authorization: Bearer $ADMIN_TKN" | jq '.[0]')

echo ${KONG_CLIENT} | jq .
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "Creating application client"

curl -s POST http://${HOST_IP}:8180/auth/admin/realms/${REALM_NAME}/clients \
  -H "Authorization: Bearer $ADMIN_TKN" \
  -H "Content-Type: application/json" \
 --data-raw '{
    "enabled": true,
    "attributes": {},
    "redirectUris": ["*"],
    "webOrigins": ["*"],
    "clientId": "myApp",
    "rootUrl": "",
    "implicitFlowEnabled": true,
    "protocol": "openid-connect"
}' | jq .
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo -e "\e[1;31m Finalised KeyCloak configuration. \e[0m\n"

echo "KeyCloak Global OIDC configuration"
curl -s http://${HOST_IP}:8180/auth/realms/${REALM_NAME}/.well-known/openid-configuration | jq .

printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
echo "Inserting above configuration and client secret to KONG"

curl -s -X POST http://${HOST_IP}:8001/plugins \
  -d name=oidc \
  -d config.client_id=kong \
  -d config.client_secret=${KONG_SECRET} \
  -d config.bearer_only=yes \
  -d config.realm=${REALM_NAME} \
  -d config.discovery=http://${HOST_IP}:8180/auth/realms/${REALM_NAME}/.well-known/openid-configuration \
  | jq .

echo "Activating CORS plugin in KONG"

curl -s -X POST http://${HOST_IP}:8001/plugins \
  -d name=cors \
  -d config.origins=* \
  -d enabled=true \
  -d config.headers=accept-tz-offset,Access-Control-Allow-Origin,Origin,Content-Type,Access-Control-Allow-Headers,Authorization,X-Requested-With \
  -d config.exposed_headers=Access-Control-Allow-Headers,Access-Control-Allow-Origin \
  -d config.credentials=true \
  -d config.max_age=3600 \
  | jq .

echo -e "\e[1;31m Finalised Kong configuration. \e[0m\n"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo -e "\e[1;31mTesting authentication \e[0m"

echo "Sending request to /$ROUTE to make sure it is blocked"
curl -s "http://${HOST_IP}:8000/${ROUTE}" \
    -H "Accept: application/json"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

RAW_TOKEN=$(curl -s -X POST \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "username=test" \
-d "password=test" \
-d 'grant_type=password' \
-d "client_id=myApp" \
http://${HOST_IP}:8180/auth/realms/${REALM_NAME}/protocol/openid-connect/token)

echo ${RAW_TOKEN}

TOKEN=$(echo ${RAW_TOKEN} | jq -r '.access_token')
echo ${TOKEN}
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

curl -s "http://${HOST_IP}:8000/${ROUTE}" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $TOKEN"

echo -e "\e[1;31m Finalised integration test. \e[0m\n"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
echo Konga admin: http://${HOST_IP}:1337 "(Please activate the kong node)"
echo KeyCloak admin: http://${HOST_IP}:8180/auth/admin
