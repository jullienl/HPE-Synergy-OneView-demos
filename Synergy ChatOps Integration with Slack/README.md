# Synergy ChatOps Integration with Slack
----

ChatOps is an approach to automate many ops-related tasks with a chat bot. 

A popular toolset for ChatOps is Slack as the chat client, and Hubot as the bot.

> Slack is a messaging app for team collaboration. More information can be found from [https://slack.com/](https://get.slack.help/hc/en-us/categories/360000049043)

Integration is what makes Slack a really interesting chat client. There are tons of integrations including bots that users can install that provide access to features from directly within the Slack interface. 

> Information about the Hubot integration can be found [here](https://slack.com/apps/A0F7XDU93-hubot)
 
Hubot is an open source chat robot that's easy to program using simple scripts written in CoffeeScript. 

These Hubot CoffeeScripts are simply calling in the background PowerShell scripts build upon the PowerShell OneView library to interact with OneView. 

So you can use Hubot to call these scripts from inside the Slack channel to automate parts of your ops-related tasks, like getting some information from OneView, deleting a server profile or provisioning a new server with an OS using the Image Streamer. All these actions can be found using the Hubot ``help`` command.

## Requirements
You will need to a have a few things ready to get a Hubot setup with Slack:

* A Windows Machine with PowerShell 4.0+. 
* Administrative access in your Slack group to create a Hubot integration

> You may get connection issues between Slack and your Hubot if your server is located behind a corporate proxy server.


## Hubot Installation
I have followed this [article](https://hodgkins.io/chatops-on-windows-with-hubot-and-powershell) and use the PowerShell DSC resource from Matthew Hodgkins to install Hubot on a Windows 2016 Server as a service, very convenient. 
> More information can be found on this [video] (https://www.youtube.com/watch?v=Gh-vYprIo7c).

## Scripts Installation
This repository provides **coffeescripts** and **PowerShell** scripts for a full integration with the HPE Synergy Composer. 
All **scripts** must be copied to your Hubot **scripts** folder (e.g. in c:\myhubot\scripts).  

## Environment Variables
It is required to define the OneView credentials and IP address. This can be done directly from the Slack channel using the Hubot commands: 
 
* `find env` - Provides the IP address of the HPE Synergy Composer and the OneView username currently set  
* `set IP <IP>` - Sets the IP address of the HPE Synergy Composer (OneView)
* `set password <password>` - Sets the password of the OneView user with Infrastructure administrator role  
* `set username <name>` - Sets the username of a OneView user with Infrastructure administrator role

## Available commands
![image](https://user-images.githubusercontent.com/13134334/59289144-aa6f6480-8c75-11e9-80f4-1e3341990573.png)
* `delete <name>` - Turns off and unprovisions a server
* `deploy centos <name>` - Deploys a CentOS 7.5 server using Image Streamer and turn it on (Note: IP is set after a reboot)
* `deploy esx <name>` - Deploys an ESXi 6.5U2 server using Image Streamer and turn it on
* `deploy rhel <name>` - Deploys a RHEL7.3 server using Image Streamer and turn it on
* `deploy sles <name>` - Deploys an SLES12 server using Image Streamer and turn it on (Note: Boot requires manual launch of grubx64.efi)
* `deploy win <name>` - Deploys a Windows 2016 server using Image Streamer and turn it on
* `deploy xen <name>` - Deploys a XenServer 7.1 server using Image Streamer and turn it on
* `get <name>` - Lists the resource avalaible in OneView (ex.: profile, network, networkset, enclosure, interconnect, uplinkset, LIG, LI, EG, LE, SPT, osdp, server, user, spp, alert)

![image](https://user-images.githubusercontent.com/13134334/59289341-1f429e80-8c76-11e9-85bc-f3850812c78c.png)


## Troubleshooting
Hubot logs can be found in the **Logs** folder of your Hubot (e.g. C:\myhubot\Logs). This is where you usually find all you need for troubleshooting.

> Remember the Hubot Windows service needs to be restarted after a modification to activate the change in Slack

## Cleaning up the Hubot help content
If you want to clean up the content of the ``help`` and keep only the ops-related tasks, you can modify **help.coffee** in **\node_modules\hubot-help\src** folder using the ``HUBOT_HELP_HIDDEN_COMMANDS``.   

Any help command you list here will be hidden from the Slack channel:

```
hiddenCommandsPattern = -> HUBOT_HELP_HIDDEN_COMMANDS="ping,adapter,echo,pug me,map me <query>,list assigned roles,the rules,pug bomb N,echo <text>,<user> doesn't have <role> role,<user> has <role> role,what roles do I have,what roles does <user> have,who has <role> role"
hiddenCommands = HUBOT_HELP_HIDDEN_COMMANDS?.split ','
new RegExp "^hubot (?:#{hiddenCommands?.join '|'}) - " if hiddenCommands
```
