#!/bin/bash

# requires - DOCKER_IMAGE

if [ -f "docker-compose.test.yml" ]; then
    docker-compose -f docker-compose.test.yml up --exit-code-from app
else
    docker run -t "$DOCKER_IMAGE" npm test
fi
