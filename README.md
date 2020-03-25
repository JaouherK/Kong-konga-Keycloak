# Kong + Konga + KeyCloak

## Goal repository

This is for development purpose as authentication interface. The Goal is to be able to protect, through the configuration of kong and keycloak, an API resource. 

## How to use this template

To run this template execute the prepare script first to pull the images and start the containers:

```shell
$ ./prepare_containers.sh
```

for windows 10+:

```shell
$ sh ./prepare_containers.sh
```

Now start the initializer script to create users and mock services and integration between all fo them:

```shell
$ ./initialize.sh
```

### Disclaimer

This docker compose file contains default credentials, so its installation is not production ready 