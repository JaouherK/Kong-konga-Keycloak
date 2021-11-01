# Kong + Konga + KeyCloak

## Goal repository

This is for development purpose as authentication interface. The Goal is to be able to protect, through the configuration of kong and keycloak, an API resource.

## Pre-requisite

- Docker installed in your machine
- jq installed in your container (VM or your laptop)

## How to use this template

To run this template, execute the "prepare" script first to pull the images and start the containers:

```shell
$ ./prepare.sh
```

for windows 10+:

```shell
$ sh ./prepare.sh
```

First of all, edit the start.sh file by setting up a public IP to access the docker containers HOST_IP="IP HERE" in this [file: start.sh](./start.sh). Default value is localhost.

Now start the initializer script to create users and mock services and integration between all fo them:

```shell
$ ./start.sh
```

## Default access credentials to admin panels

### Konga/Kong

- url: http://localhost:1337
- login: admin@test.com
- pass: 00000000

### Keycloak

- url: http://localhost:8180/
- login: admin
- pass: admin

### Disclaimer

This docker compose file contains default credentials, so its installation is not production ready 
