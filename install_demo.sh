#!/usr/bin/env bash

main() {
    # If the argument is empty then run both functions else only run provided function as argument $1.
    [ -z "$1" ] && { deploy_demo; } || $1     
}

deploy_demo () {
   echo -e "\nUpdating helm repos"
   helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >> /dev/null
   helm repo add newrelic https://helm-charts.newrelic.com >> /dev/null
   helm repo update >> /dev/null
   echo -e "\nRepos updated"
   echo -e "\nCreate namespace newrelic and otel-demo" 
   kubectl create namespace newrelic
   kubectl create namespace otel-demo

   while true; do
      if [[ $OSTYPE == 'darwin'* ]]; then
         # Running on macos
         if [ -s browseragent.js ]; then
            # The file is not-empty.
            sed -i '' '/<script type="text\/javascript">/g' browseragent.js
            sed -i '' '/<\/script>/g' browseragent.js
            echo -e "\nBrowser agent file has been updated"
            kubectl create configmap newrelic-otel-browseragent --from-file=browseragent.js=browseragent.js -o yaml --dry-run=client -n otel-demo | kubectl apply -f -
            break
         else
            # The file is empty.
            echo -e "\nPlease add New Relic browser script to browseragent.js"
            sleep 15
         fi
      
      else
         # Not running on macos
         if [ -s browseragent.js ]; then
            # The file is not-empty.
            sed -i '/<script type="text\/javascript">/g' browseragent.js
            sed -i '/<\/script>/g' browseragent.js
            echo -e "\nBrowser agent file has been updated"
            kubectl create configmap newrelic-otel-browseragent --from-file=browseragent.js=browseragent.js -o yaml --dry-run=client -n otel-demo | kubectl apply -f -
            break
         else
            # The file is empty.
            echo -e "\nPlease add New Relic browser script to browseragent.js"
            sleep 15
         fi
      fi
   done

   while true; do
      echo -e "\nEnter your ingest license key: "
      read -t 60 licenseKey
      if [ -z $licenseKey ]; then
         echo -e "\nLicense Key can't be empty"
         continue
      fi
      break
   done

   while true; do
      echo -e "\nSpecify your New Relic datacenter: [US/EU]"
      read -t 60 datacenter
      if [ -z $datacenter ]; then
         echo -e "You need to choose a datacenter"
         continue
      fi
      break
   done

   echo -e "\nInstalling New Relic kubernetes integration"
   helm upgrade --install newrelic-bundle newrelic/nri-bundle  --version 5.0.81 --set global.licenseKey=$licenseKey --namespace=newrelic --values ./newrelic_values.yaml >> /dev/null
   echo -e "\nNew Relic kubernetes integration deployed"

   echo -e "\nInstalling otel demo\n"
   kubectl create secret generic newrelic-key-secret --save-config --dry-run=client --from-literal=new_relic_license_key=$licenseKey -o yaml -n otel-demo | kubectl apply -f - 2>&1
   

   if [[  $(echo $datacenter | tr '[:upper:]' '[:lower:]') ==  "eu" ]]; then
      helm upgrade --install newrelic-otel open-telemetry/opentelemetry-demo -n otel-demo --values ./otel_values.yaml --version 0.31.0 --set opentelemetry-collector.config.exporters.otlp.endpoint="otlp.eu01.nr-data.net:4318" >> /dev/null
   else
      helm upgrade --install newrelic-otel open-telemetry/opentelemetry-demo -n otel-demo --values ./otel_values.yaml --version 0.31.0 >> /dev/null
   fi

   echo -e "\nOTEL demo deployed"

   echo -e "\nWaiting for pods to be ready, this can take while, please wait..."
   sleep 3
   wait_for_pods
   sleep 3
   clear
   echo -e "\nChecking frontend is ready to serve\n"
   #Double check frontend is ready to serve, or send error to terminal
   kubectl wait pod --for=condition=Ready --timeout=300s -l app.kubernetes.io/component=frontend -n otel-demo
   kubectl wait pod --for=condition=Ready --timeout=300s -l app.kubernetes.io/component=frontendproxy -n otel-demo
   echo -e "\nDemo deployed"
   clear
   echo -e "\nRun this command if you want to access frontend on http://localhost:8080/"
   echo -e "\nkubectl --address 0.0.0.0 port-forward --pod-running-timeout=24h svc/newrelic-otel-frontendproxy -n otel-demo 8080:8080"
}


wait_for_pods () {
   # expecting at least 20 pods for otel demo
   declare -i numberpodsexpected=19
   declare -i currentnumberpods=0
   
   while [[ $numberpodsexpected -ge $currentnumberpods ]];do
      clear
      kubectl get pods -n otel-demo
      currentnumberpods=$(kubectl get pods --field-selector=status.phase!=Succeeded,status.phase=Running --output name -n otel-demo | wc -l | tr -d ' ')
      sleep 5
   done
   sleep 2
   clear
}

main "$@"