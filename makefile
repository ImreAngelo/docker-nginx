BASE_IMAGE=angelo/nginx
DEV_IMAGE=nginx-dev
VERSION=1.0.0

.PHONY: all base dev test

all: base dev test

base:
	docker build -f ./src/Dockerfile -t $(BASE_IMAGE):latest .

dev: base
	docker build --build-arg BASE_IMAGE=$(BASE_IMAGE) -f ./src/Dockerfile.dev -t $(BASE_IMAGE):development .

test: dev
	docker compose -f 'docker-compose.yml' up -d --build 