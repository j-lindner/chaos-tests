#!/bin/bash
set -euo pipefail

testScenarioName=${1:-'example'}

TESTRUNS_DIR="testruns"
dashboardId="zeebe-dashboard"
dashboardName="zeebe"

echo "###############################################"
echo "Running test for config: ${testScenarioName}"

# Start Zeebe
echo 'Starting Zeebe...'
(cd "${TESTRUNS_DIR}/${testScenarioName}" && make camunda)

# get the start time of the benchmark
# Note that grafana expects timestamps as millis since epoch
startTime=$(date +%s000)
startTimeIso=$(date +"%Y-%m-%d %H:%M:%S")
echo "start time = $startTimeIso"

# execute dynamic sleep in generated run.sh file
(cd "${TESTRUNS_DIR}/${testScenarioName}" && source run.sh)
# TODO run c8b as a job (see: https://github.com/falko/zeebe-benchmark/blob/hackdays-2020/Dockerfile#L28) and wait the job to be finished, e.g. using:
#kubectl wait --for=condition=complete job/starter --timeout=1200s

# get the endtime of the benchmark
endTime=$(date +%s000)
endTimeIso=$(date +"%Y-%m-%d %H:%M:%S")
echo "end time = $endTimeIso"

# cleanup
echo 'Finished. Cleaning up now...'
(cd "${TESTRUNS_DIR}/${testScenarioName}" && make clean)

# Generate Dashboard Links

echo 'Getting Graphana URL'
grafanaUrl=$(cd "${TESTRUNS_DIR}/${testScenarioName}" && make url-grafana)
#grafanaUrl="http://34.73.2.98/d/I4lo7_EZk/zeebe?var-namespace=camunda"
echo $grafanaUrl

#http://34.73.2.98/d/uX16GP3nk/zeebe-low-latency?orgId=1&from=1656406606147&to=1656407414704&var-DS_PROMETHEUS=Prometheus&var-namespace=camunda&var-pod=All&var-partition=All

#get and parse dashboard id
#parse the IP Address from the base grafana url
ipAddress="$(grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' <<< "$grafanaUrl")"

# create the url to the low-latency dashboard in the correct time frame
grafanaUrl="http://$ipAddress/d/$dashboardId/$dashboardName?orgId=1&from=$startTime&to=$endTime&var-DS_PROMETHEUS=Prometheus&var-namespace=camunda&var-pod=All&var-partition=All"
#echo $grafanaUrl

if [ ! -d "$TESTRUNS_DONE_DIR" ]; then
  mkdir $TESTRUNS_DONE_DIR
fi

#create a csv with the params (link to dashboard) (toTime) (fromTime) (id of dashboard)
csvFile="$TESTRUNS_DONE_DIR/grafanalinks.csv"
if [ -e $csvFile ]
then
   echo "writing line $csvFile"
   echo "\"=HYPERLINK(\"\"$grafanaUrl\"\", \"\"$testScenarioName\"\")\"", "\"$startTimeIso\"", "\"$endTimeIso\"" >> $csvFile
else
   echo "creating file $csvFile"
   touch $csvFile
   echo "Scenario", "Start Time", "End Time" >> $csvFile
   echo "\"=HYPERLINK(\"\"$grafanaUrl\"\", \"\"$testScenarioName\"\")\"", "\"$startTimeIso\"", "\"$endTimeIso\"" >> $csvFile
fi

if [ ! -d "${TESTRUNS_DONE_DIR}/${testScenarioName}" ]
then
  mv "${TESTRUNS_DIR}/${testScenarioName}" "${TESTRUNS_DONE_DIR}/"
else
  rm -rf "${TESTRUNS_DIR}/${testScenarioName}"
fi

# immediately persist test config
#cp -r ../src/main/resources "${TESTRUNS_DONE_DIR}/zeebe-tuner-config"
#cd $TESTRUNS_DONE_DIR
#git add . && git commit . -m "Add benchmark run ${testScenarioName}" && git push
#cd -

echo "Benchmark ${testScenarioName} has been completed."