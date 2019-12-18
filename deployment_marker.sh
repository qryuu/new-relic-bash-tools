#!/bin/bash

#parameters
api_key="Admin user API key" #Required
application_id="application_id" #Required
deploy_revision="deploy-revision" #Required
deploy_changelog="" #option
deploy_description=""  #option
deploy_user="" #option

#parameter-check
if [ "${api_key}" = "" -o "${api_key}" = "Admin user API key" ]; then
echo "Please set API Key."
elif [ "${application_id}" = "" -o "${application_id}" = "application_id" ]; then
echo "Please set application id."
elif [ "${deploy_revision}" = "" -o "${deploy_revision}" = "deploy-revision" ]; then
echo "Please set deploy revision."
else

#API Request
cat <<EOL | /bin/bash
curl -X POST "https://api.newrelic.com/v2/applications/${application_id}/deployments.json" \
     -H "X-Api-Key:${api_key}" -i \
     -H 'Content-Type: application/json' \
     -d \
'{
  "deployment": {
    "revision": "${deploy_revision}",
    "changelog": "${deploy_changelog}",
    "description": "${deploy_description}",
    "user": "${deploy_user}"
  }
}'
EOL
fi