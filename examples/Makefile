all:
	docker-compose up -d && \
	sleep 2 && \
	docker-compose exec postgres psql -U postgres -1f /mnt/deploy/deploy.sql

clean:
	docker-compose down
