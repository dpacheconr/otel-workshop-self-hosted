#!/usr/bin/env bash

main() {
    # If the argument is empty then run both functions else only run provided function as argument $1.
    [ -z "$1" ] && { uninstall_demo; } || $1     
}

uninstall_demo () {
   echo -e "\nDeleting helm releases"
   helm delete newrelic-otel -n otel-demo 
   helm delete newrelic-bundle -n newrelic 
   echo -e "\nDeleting secrets and configmaps"
   kubectl delete secret newrelic-key-secret -n otel-demo 
   kubectl delete cm newrelic-otel-browseragent -n otel-demo
   echo -e "\nDeleting namespace newrelic"
   kubectl delete namespace newrelic
   kubectl delete namespace otel-demo
}

main "$@"