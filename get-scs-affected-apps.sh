#!/bin/bash

#set -eox pipefail

# PREREQUISITES
# - User must be logged in with UAA admin credentials before executing this script.
# - CF SSH permission must be enabled.
# - The jq executable must be on the $PATH
#

DATE=`date`
echo "Scan for profiles - $DATE"
export ORG='p-spring-cloud-services'
cf t -o $ORG >/dev/null 2>&1
cf spaces |
while read SPACE
do
  STR_LENGTH=`echo $SPACE | wc -c`
  if [ $STR_LENGTH -eq 37 ]
  then
    echo "==========================================================================="
    SI_CURL=`cf curl /v2/service_instances/$SPACE`
    SERVICE_NAME=`echo $SI_CURL | jq '.entity.name'`

    SPACE_URL=`echo $SI_CURL | jq '.entity.space_url' | sed -e 's/^"//' -e 's/"$//' `
    # echo "SPACE_URL -- $SPACE_URL"

    SPACE_CURL=`cf curl $SPACE_URL`
    # echo "ORG-CURL -- $SPACE_CURL"
    ORG_URL=`echo $SPACE_CURL| jq '.entity.organization_url' | sed -e 's/^"//' -e 's/"$//' `
    #echo "ORG_URL -- $ORG_URL"
    ORG_CURL=`cf curl $ORG_URL`

    SPACE_NAME=`echo $SPACE_CURL | jq '.entity.name'`
    ORG_NAME=`echo $ORG_CURL | jq '.entity.name'`

    if [[ $SI_CURL =~ "config-server" ]]
    then
      cf t -o $ORG -s $SPACE
      echo "---------------------------------------------------------------------------"
      echo "ORG          - $ORG_NAME"
      echo "SPACE        - $SPACE_NAME"
      echo "SERVICE NAME - $SERVICE_NAME"
      echo "SI GUID      - $SPACE"
      echo ""
      cf apps |
      while read APP
      do
        if [[ $APP =~ "config-server" ]]
        then
          echo "CHECKING FOR USAGE OF DEPRECATED spring.profiles IN $SERVICE_NAME"
          echo "---------------------------------------------------------------------------"
          cf ssh config-server -c "grep -iRH profiles /home/vcap/app/config-repo-default/*" 
          echo "---------------------------------------------------------------------------"
          
          ### Find apps bound to this service
          echo ""
          echo "APPS BOUND TO $SERVICE_NAME"
          echo "---------------------------------------------------------------------------"
          BINDINGS=$(cf curl "/v2/service_instances/$SPACE/service_bindings")
          for APP_URL in $(echo "${BINDINGS}" | jq -r '.resources[].entity.app_url'); do
            #echo "App URL: $APP_URL"
            APP=`cf curl $APP_URL`
            APP_GUID=`echo $APP | jq --raw-output '.metadata.guid'`
            APP_NAME=`echo $APP | jq --raw-output '.entity.name'`
            #echo "App name: $APP_NAME"
            APP_SPACE_URL=`echo $APP | jq --raw-output '.entity.space_url'`
            #echo "App space URL: $APP_SPACE_URL"
            APP_SPACE=`cf curl $APP_SPACE_URL`
            #echo "App space: $APP_SPACE"
            APP_SPACE_NAME=`echo $APP_SPACE | jq --raw-output '.entity.name'`
            #echo "App space name: $APP_SPACE_NAME"
            APP_ORG_URL=`echo $APP_SPACE | jq --raw-output '.entity.organization_url'`
            APP_ORG=`cf curl $APP_ORG_URL`
            #echo "App org: $APP_ORG"
            APP_ORG_NAME=`echo $APP_ORG | jq --raw-output '.entity.name'`
            #echo "App org name: $APP_ORG_NAME"

            # Fetch the Spring Boot version of the app
            cf target -o $APP_ORG_NAME -s $APP_SPACE_NAME >/dev/null 2>&1
            BOOT_VERSION=`cf ssh $APP_NAME -c "grep -iRH Spring-Boot-Version /home/vcap/app/META-INF/MANIFEST.MF" | sed -e 's/.* //' -e 's/\n$//'`

            echo "org: $APP_ORG_NAME, space: $APP_SPACE_NAME, app: $APP_NAME, app_guid: $APP_GUID, boot-version: $BOOT_VERSION"
          done
          echo "==========================================================================="
          echo ""
        fi
      done
    fi
  fi
done
