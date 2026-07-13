.PHONY: up down logs test build

up:
	docker compose up --build -d

down:
	docker compose down -v

logs:
	docker compose logs -f api

build:
	docker compose build

test:
	docker compose run --rm --no-deps api pytest -q
