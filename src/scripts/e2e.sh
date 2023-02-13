#!/bin/bash

# requires - DOCKER_IMAGE

if [ -f "docker-compose.e2e.yml" ]; then
    docker-compose -f docker-compose.e2e.yml up --exit-code-from app
else
    docker run -t "$DOCKER_IMAGE" npm run e2e
fi
