#!/bin/sh

# Run the Slack update script with admin privilege ('osascript' would prompt for password)
# NOTE: This is a workaround to get generated Platypus 
# bundled app to run as super user.
app_bundle_id='com.bashtheshell.slackautoupdater'
osascript -e "do shell script \"./${app_bundle_id}/slack_update.sh 2>&1 >/tmp/${app_bundle_id}_manually_ran.log\" with administrator privileges"
