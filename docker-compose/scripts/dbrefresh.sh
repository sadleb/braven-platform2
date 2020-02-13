#!/bin/bash
echo "Refreshing your local dev database"

docker-compose down
docker volume rm platform_db-platform
docker-compose up -d
sleep 5 # wait for containers to be up and accepting connections

docker-compose exec platformweb bundle exec rake db:create db:schema:load db:dummies



