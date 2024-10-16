docker-login:
    source .env && docker login --username "$DOCKER_USER" --password "$DOCKER_PASS" reg.ambrosys.de

docker-logout:
    docker logout reg.ambrosys.de
