IMAGE_NAME=angelo/nginx
VERSION=1.0.0

.PHONY: all base dev test

all: base dev

build:
	docker build -f ./src/Dockerfile -t $(IMAGE_NAME):latest .

dev: build
	docker build --build-arg BASE_IMAGE=$(IMAGE_NAME) -f ./src/Dockerfile.dev -t $(IMAGE_NAME):development .

test: dev
	docker compose -f 'docker-compose.yml' up -d --build 

ci:
	docker build --build-arg BASE_IMAGE=$(IMAGE_NAME) -f ./src/Dockerfile.dev -t $(IMAGE_NAME):latest .