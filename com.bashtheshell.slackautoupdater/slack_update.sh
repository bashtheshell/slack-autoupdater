#!/usr/bin/env bash

# Check if slack.com is reachable or else exit script
curl -sL 'https://slack.com/release-notes/mac/rss' 2>&1 >/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Unable to reach slack.com on $(date). System may be offline. This script will now exit."
    exit 10
fi

# Get the latest Slack version (pulls version from 'Slack for Mac' download page)
currentSlackVersion=$(curl -o /dev/null -sIw '%{redirect_url}' https://slack.com/ssb/download-osx | grep -Eo 'Slack-[0-9]+\.[0-9]+\.[0-9]+' | cut -c 7-20 | head -n 1 )
# NOTE: This used to be effective until sometimes Slack would rollback the downloable DMG file version. This is kept for references.
# currentSlackVersion=$(curl -sL 'https://slack.com/release-notes/mac/rss' | grep -Eo 'Slack-[0-9]+\.[0-9]+\.[0-9]+' | cut -c 7-20 | head -n 1 )


#### Install Slack function

install_slack() {
	
# Slack download variables
slackDownloadUrl=$(curl "https://slack.com/ssb/download-osx" -s -L -I -o /dev/null -w '%{url_effective}')
dmgName=$(printf "%s" "${slackDownloadUrl[@]}" | sed 's@.*/@@')
slackDmgPath="/private/tmp/$dmgName"


### Begin Download

# Detach Slack DMG volume if already mounted
if [ ! -z "$(ls -d /Volumes/Slack* 2>/dev/null)" ]; then
    echo 'Ejecting the DMG volume...'
    hdiutil detach /Volumes/Slack*
fi

# Downloads latest version of Slack or else exit script if download fails
echo "Downloading latest Slack app (${dmgName})..."
curl -L -o "$slackDmgPath" "$slackDownloadUrl"
if [ $? -ne 0 ]; then
    echo "ERROR: Unable to download Slack. System may be offline. This script will now exit."
    exit 10
fi

# Mounts the DMG volume
echo 'Mounting the DMG volume...'
hdiutil attach -nobrowse $slackDmgPath

# Obtain a list of users actively have Slack open
active_slack_users=""
while read -r per_process_user_in_redirect ; do
    if [[ -z "$active_slack_users" ]]
    then
        active_slack_users="${per_process_user_in_redirect}"
    else
        active_slack_users="${active_slack_users}
${per_process_user_in_redirect}"
    fi
done <<< "$(ps -o user= -p $(pgrep '[Ss]lack') | sort | uniq )"

# Set notification prompt title
notification_title="Slack AutoUpdater"

# Kill Slack if still running
if [ ! -z "$(pgrep '[Ss]lack')" ]; then
    # Warn user that Slack app will close in 30 seconds for update
    # NOTE: This assumes only one user's actively using Slack. Improvement can be made here later for multi-user logins.
    while read -r per_process_user_in_redirect ; do
        echo "Warn user - ${per_process_user_in_redirect} - that Slack update will reload in 30 seconds..."
        su - ${per_process_user_in_redirect} -c "osascript -e 'display notification \"A new version of Slack is now available for update. Slack will reload in about 30 seconds.\" with title \"${notification_title}\"'"
        sleep 30
        echo "Prompt user - ${per_process_user_in_redirect} - that Slack will now reload..."
        su - ${per_process_user_in_redirect} -c "osascript -e 'display notification \"Slack is now close for update.\" with title \"${notification_title}\"'"
    done <<< "$active_slack_users"

    echo "Closing Slack..."
    killall -SIGKILL "Slack"
fi

# Remove the existing Application if exists
if [ -d "/Applications/Slack.app" ]; then
    echo 'Uninstalling existing Slack app from "/Applications" directory...'
    rm -rf /Applications/Slack.app
fi

# Copy the updated app into /Applications folder
echo 'Installing new Slack version...'
ditto -rsrc /Volumes/Slack*/Slack.app /Applications/Slack.app

# Re-open Slack app if open before update
while read -r per_user_in_redirect ; do
    echo 'Opening Slack app...'
    su - ${per_user_in_redirect} -c 'open /Applications/Slack.app'

    # Notify user that Slack update is now complete
    su - ${per_user_in_redirect} -c "osascript -e 'display notification \"Slack is now up to date. Thank you.\" with title \"${notification_title}\"'"
done <<< "$active_slack_users"

# Unmount and eject the DMG volume
echo 'Ejecting the DMG volume...'
hdiutil detach /Volumes/Slack.app

# Clean up the downloaded files in /tmp directory
echo 'Cleaning up temporary files...'
rm -rf "$slackDmgPath"

}



# Update-ownership function
update_ownership() {
	echo 'Updating ownership on "/Applications/Slack.app" directory...'
	chown -R root:wheel "/Applications/Slack.app"
}


### Main ###


# Install if Slack isn't installed
if [ ! -d "/Applications/Slack.app" ]; then
    echo "Slack app is not installed. Latest version is ${currentSlackVersion}. Now installing Slack..."
	install_slack
	update_ownership
    printf "Slack is now installed. Version: %s. \nDate: $(date). Exiting now...\n" "$localSlackVersion"
    exit 0
else
    localSlackVersion=$(defaults read "/Applications/Slack.app/Contents/Info.plist" "CFBundleShortVersionString")

    slack_rollback() {
        echo "Slack app appears to be rolled back. (currently on ${localSlackVersion} and new version is ${currentSlackVersion}). Now updating Slack..."
        install_slack
        update_ownership
        localSlackVersion=$(defaults read "/Applications/Slack.app/Contents/Info.plist" "CFBundleShortVersionString")
        printf "Slack is now up-to-date. Version: %s. \nDate: $(date). Exiting now...\n" "$localSlackVersion"
        exit 0
    }

    slack_update() {
        echo "Slack app is NOT up to date (currently on ${localSlackVersion} and new version is ${currentSlackVersion}). Now updating Slack..."
        install_slack
        update_ownership
        localSlackVersion=$(defaults read "/Applications/Slack.app/Contents/Info.plist" "CFBundleShortVersionString")
        printf "Slack is now up-to-date. Version: %s. \nDate: $(date). Exiting now...\n" "$localSlackVersion"
        exit 0
    }

    # Otherwise, update if existing Slack version is not current
    if (( $(echo "$(echo $currentSlackVersion | sed 's/\..*$//') < $(echo $localSlackVersion | sed 's/\..*$//')" | bc -l ) ))
    then
        slack_rollback
    elif (( $(echo "$(echo $currentSlackVersion | sed 's/\..*$//') > $(echo $localSlackVersion | sed 's/\..*$//')" | bc -l ) ))
    then
        slack_update
    else 
        if (( $(echo "$(echo $currentSlackVersion | sed 's/^[0-9]*\.//') < $(echo $localSlackVersion | sed 's/^[0-9]*\.//')" | bc -l ) ))
        then
            slack_rollback
        elif (( $(echo "$(echo $currentSlackVersion | sed 's/^[0-9]*\.//') > $(echo $localSlackVersion | sed 's/^[0-9]*\.//')" | bc -l ) ))
        then
            slack_update    
        else
            # Else, exit if Slack app is already current
            printf "Slack is already up-to-date. Version: %s. \nDate: $(date). Exiting now...\n" "$localSlackVersion"			
            exit 0
        fi
    fi
fi

