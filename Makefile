.PHONY: up down logs backup restore deploy

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f mlflow

backup:
	./scripts/backup.sh

restore:
	./scripts/restore.sh $(DIR)

deploy:
	./scripts/deploy.sh
