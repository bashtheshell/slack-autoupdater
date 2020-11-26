# Slack Autoupdater for macOS


## Summary:
The Autoupdater would allow Slack app to automatically update or roll back itself behind the scene without having it prompting the pesky "helper tool" pop-ups. 

The use case for this application is mainly for Slack users who aren't power users on their macOS system as only administative users can perform updates. While this may be a rare case for many, this application may be useful in some organizations as some users aren't able to update the apps themselves.

Yes, Slack has already provided this ability as mentioned in their [article](https://slack.com/help/articles/360035635174-Deploy-Slack-for-macOS#allow-users-to-update-slack). However, this approach requires maintaining a copy of the application in each user's home directory. Can you fathom the problem here? It's far more manageable for a desktop adminstrator to manage a fleet knowing there's only one Slack app to manage per machine.


## Building the App:

Before you can begin using the app, you'd need to build the application bundle so that you can customize the app however you like with your own information. The app was created using Sveinbjorn Thordarson's [Platypus (v5.3)](https://github.com/sveinbjornt/Platypus/tree/5.3) app, which can be installed via Homebrew. `brew cask install platypus` is all you need. At the time of this writing, macOS Catalina was used. You'd also need to install the command-line tool for Platypus through [_Platypus Preferences_](https://github.com/sveinbjornt/Platypus/blob/5.3/Documentation/Documentation.md#preferences) settings.


Make this `slack-autoupdater` repository the current directory before running the following:

```shell
/usr/local/bin/platypus \
    --name 'Slack AutoUpdater' \
    --interface-type 'None' \
    --interpreter '/bin/sh' \
    --app-icon '' \
    --app-version '1.0' \
    --author 'Travis Johnson' \
    --bundle-identifier 'com.bashtheshell.slackautoupdater' \
    --bundled-file './com.bashtheshell.slackautoupdater' \
    --quit-after-execution \
    './com.bashtheshell.slackautoupdater/main.sh' \
    --overwrite \
    ./build/'Slack AutoUpdater'
```

As a result, `Slack AutoUpdater.app` application bundle would be created in the `./build` directory.

Please note that Platypus doesn't provide a way for us to run the application bundle as privilege user when using the Bash script directly. This seemed to be a known bug. As a workaround, the `main.sh` script is actually an `osascript` wrapper script that would call the `slack_update.sh` script.

## Packaging the App for Deployment:

The `pkgbuild` command would be used to create the Installer (.pkg) file. This is also a good opportunity for an organization to certify the package.

While in the `slack-autoupdater` directory, run:

```shell
pkgbuild \ 
    --identifier com.bashtheshell.slackautoupdater \
    --version 1.0 \
    --root ./build/Slack\ AutoUpdater.app  \
    --scripts ./build/Slack\ AutoUpdater.app/Contents/Resources/com.bashtheshell.slackautoupdater/installer_scripts/ \
    --install-location /Applications/Slack\ AutoUpdater.app \
    ./build/com.bashtheshell.slackautoupdater.pkg
```

The resulting `.pkg` file should also be in the `./build` directory. After completing the installation using the package file, the new app should be in the `/Applications` directory.

You can also distribute the package file to other users.

## How It Works?

After installing the package, the Autoupdater would immediately run and every 10 minutes hereafter, checking to see if your copy of Slack is in sync with the downloadable production version. Even it would roll back your copy if Slack also roll back the production version as shown on their [download page](https://slack.com/downloads/mac). If the Slack app is open on the computer prior to the update, the Autoupdater would re-open the app after updating.

Special thanks to shaquir's [script](https://github.com/shaquir/ShellScript/blob/b7c1af2a7a1ddb00951fc3900cc3872704c3b028/installSlack.sh), many improvements have been made to the [slack_update.sh](./com.bashtheshell.slackautoupdater/slack_update.sh) script as it's the main driving force behind the Autoupdater app.

Last but not least, the [`postinstall`](./com.bashtheshell.slackautoupdater/installer_scripts/postinstall) script, from the Installer file, would install the Launch Daemon script using the [com.bashtheshell.slackautoupdater.plist](./com.bashtheshell.slackautoupdater/com.bashtheshell.slackautoupdater.plist) plist file to be run persistently, checking for Slack update every 10 minutes.

Why 10 minutes? It's arbitrarily decided but was done with careful considerations. 99% of the time, the updates haven't went over 10 minutes. Also, when Slack released a new production version, usually Slack's native updater would not prompt for an update on that same day. Theoretically, the Autoupdater would check for update 144 times per day. However, this value can be changed in the `com.bashtheshell.slackautoupdater.plist` file.

Here's the 10-minute value:

```xml
<key>StartInterval</key>
<integer>600</integer>
```

You can verify that the Launch Daemon is running using the command:

```shell
sudo launchctl list | grep com.bashtheshell.slackautoupdater
```

It's important that the command's run by root user. If it's not present, chances are the plist file is missing from `/Library/LaunchDaemons` directory. To correct this problem, just re-install the package.

To see the continuous command outputs from the Autoupdater, run the following. Please note that the logs may be cleared at the next boot.

```shell
tail -f /tmp/com.bashtheshell.slackautoupdater.stdout
```

## How to Uninstall?

Easy! Just uninstall the Autoupdater app from `/Applications` directory. The Launch Daemon service would remove itself within 10 minutes after.

## Known Issues?

At this time, the only issue is the security implication, using the Launch Daemon, as it's basically a Linux's equivalence of `cronjob` that's run by root. It's strongly recommended to carefully review the scripts in this repository.
