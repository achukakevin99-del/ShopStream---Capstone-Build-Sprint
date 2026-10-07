include .env
export

up:            ; docker compose up -d
migrate:       ; flyway -configFiles=flyway.conf clean migrate
migrate-docker:
	docker run --rm --network host -v $(PWD)/db/migration:/flyway/sql flyway/flyway:10 \
	  -url=jdbc:postgresql://localhost:5432/$(PGDATABASE) -user=$(PGUSER) -password=$(PGPASSWORD) \
	  -cleanDisabled=false clean migrate
roles:         ; ./scripts/setup_roles.sh
security:      ; ./scripts/verify_security.sh
optimize:      ; ./optimization/run_optimization.sh
backup:        ; ./scripts/backup.sh
restore-test:  ; ./scripts/restore_test.sh
demo:          ; python3 -m app.demo
