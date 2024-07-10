#!/usr/bin/env bash

main() {
    # If the argument is empty then run both functions else only run provided function as argument $1.
    [ -z "$1" ] && { build_frontend; } || $1     
}

build_frontend () {
    echo "\n Building frontend image, this may take while" 
    mkdir -p ./src/ && \
    wget https://github.com/open-telemetry/opentelemetry-demo/archive/refs/tags/1.10.0.zip && \
    unzip 1.10.0.zip && \
    cp -R ./opentelemetry-demo-1.10.0/src/frontend ./src/ && \
    cp -R ./opentelemetry-demo-1.10.0/pb . && \
    cp _document.tsx ./src/frontend/pages

    docker compose build frontend && docker compose push frontend

    rm -rf 1.10.0.zip opentelemetry-demo-1.10.0 frontend pb src
}

main "$@"