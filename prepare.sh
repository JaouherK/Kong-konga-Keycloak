#!/bin/bash

echo "Make sure jq is installed in the system"
sudo apt install jq -y
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "Starting KeyCloak db and KeyCloak"
docker-compose up -d keycloak-db
docker-compose up -d keycloak
echo "Wait time until KeyCloak starts i.e 10Seconds"
sleep 10s
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "Building kong container"
docker-compose build kong
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "Starting Kong DB (Postgres) and making migration"
docker-compose up -d db
sleep 5s
docker-compose run --rm kong kong migrations bootstrap
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

echo "Starting Kong + Konga"
docker-compose up -d kong
docker-compose up -d konga
echo "Wait time until Kong starts i.e 20Seconds"
sleep 20s
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
