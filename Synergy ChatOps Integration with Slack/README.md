# Synergy ChatOps Integration with Slack
----

ChatOps is an approach to automate many ops-related tasks with a chat bot. 

## Description

The purpose of this integration is to provide ChatOps operation with a HPE Synergy environment from a mobile app (= possibility to use a smartphone/tablet) using a [chatbot]( https://www.expertsystem.com/chatbot/).

A Chatbot is often described as a computer program or an artificial intelligence software that can simulate a conversation (or a chat) with a user. In this integration, we are going to use a ChatBot engine to interact directly with HPE OneView using chat messages from a **Slack** workspace (the mobile app).  

> **Slack** is a messaging app for team collaboration. More information can be found from [https://slack.com/](https://get.slack.help/hc/en-us/categories/360000049043)   
> Integration is what makes Slack a really interesting chat client. There are tons of integrations including bots that users can install that provide access to features from
> directly within the Slack interface.

![image](https://user-images.githubusercontent.com/13134334/59289960-a6dcdd00-8c77-11e9-8d87-53de017e2460.png)

Using simple chat messages sent to the Chatbot, the robot assistant will analyze the request, identify and run the action against the Synergy environment and then return the response. 

The scripts I provide in this repo can enable the ChatBot **Hubot** to provide information about many resources in HPE OneView but can also enable the ChatBot to fully compose/decompose the Synergy infrastructure automatically by provisioning/un-provisioning HPE Synergy servers with an OS fully configured.

> **Hubot** is an open source chatbot that's easy to program and interact with using scripts written in [CoffeeScript](https://en.wikipedia.org/wiki/CoffeeScript).  
> Information about the Hubot integration can be found [here](https://slack.com/apps/A0F7XDU93-hubot)

![image](https://user-images.githubusercontent.com/13134334/59511848-9f0b7b80-8eb7-11e9-928a-fb59f04aa28e.png)

### In the background: 
* Slack is securely connected to the Hubot engine located next to the HPE Synergy infrastructure
* Hubot CoffeeScripts are simply calling PowerShell scripts in the background to interact with HPE OneView. 
* The PowerShell scripts use the HPE OneView PowerShell library to control the HPE Synergy Composer 
* For the workload composition, the Servers are provisioned automatically via Synergy Server Profile Templates and HPE Image Streamer 


## Requirements
You will need to a have a few things ready to get a Hubot setup with Slack:

* A Windows Machine with PowerShell 4.0+ and with administrative access
* [HPE OneView 4.20 PowerShell library](https://github.com/HewlettPackard/POSH-HPOneView) must be installed on the Windows Machine
* Administrative access in your Slack group to create a Hubot integration
* Hubot commands for automated server provisioning and deployment require the creation of Server Profile Templates using HPE Image Streamer OS Deployment plans in HPE OneView

> You may get connection issues between Slack and your Hubot if your Windows Machine is located behind a corporate proxy server.


## Hubot Installation
I have followed this [article](https://hodgkins.io/chatops-on-windows-with-hubot-and-powershell) and use the PowerShell DSC resource from Matthew Hodgkins to install Hubot on a Windows 2016 Server as a service, very convenient. 
> Detailed installation steps are described in this [video](https://www.youtube.com/watch?v=Gh-vYprIo7c).

## Scripts Installation

This repository provides **coffeescripts** and **PowerShell** scripts for a full integration with the HPE Synergy Composer. 
All **scripts** must be copied to your Hubot **scripts** folder (e.g. in c:\myhubot\scripts).  

Once all scripts are present in \scripts, the Hubot Windows service needs to be retarted to activate the new commands in Slack.
Hubot will then be able to call these scripts from inside the Slack channel.

## Scripts personalization
Each `deploy-<OS>server.ps1` PowerShell script must be modified with the corresponding Server Profile Template name present in HPE OneView. 
 
```
 function deploy-rhelserver {
    [CmdletBinding()]
    Param
    (
        # Server name
        [Parameter(Mandatory = $true)]
        $name 
    )
 
 
    # Server Profile Template name to use for the deployment
    $serverprofiletemplate = "RHEL7.3 deployment with Streamer"

```

## Available commands
From the Slack channel, you can automate parts of your ops-related tasks, like getting some information from OneView, deleting a server profile or provisioning a new server with an OS using the Image Streamer. All these actions can be found using the Hubot ``help`` command or `help <command>`:

![image](https://user-images.githubusercontent.com/13134334/59419033-62158b00-8dca-11e9-8954-63ea7ea4cc28.png)

* `delete <name>` - Turns off and unprovisions a server
* `deploy centos <name>` - Deploys CentOS 7.5 on a free server resource using Image Streamer and turn it on 
* `deploy esx <name>` - Deploys ESXi 6.5U2 on a free server resource using Image Streamer and turn it on
* `deploy rhel <name>` - Deploys RHEL7.3 on a free server resource using Image Streamer and turn it on
* `deploy sles <name>` - Deploys SLES12 on a free server resource using Image Streamer and turn it on 
* `deploy win <name>` - Deploys Windows 2016 server on a free server resource using Image Streamer and turn it on
* `deploy xen <name>` - Deploys XenServer 7.1 on a free server resource using Image Streamer and turn it on
* `get <name>` - Lists the resource available in OneView (ex.: profile, network, networkset, enclosure, interconnect, uplinkset, LIG, LI, EG, LE, SPT, osdp, server, user, spp, alert)

![image](https://user-images.githubusercontent.com/13134334/59513194-a4b69080-8eba-11e9-9489-ee2b5a390a80.png)

> Automated provisioning and deployment of server when using `deploy <OS> <name>` commands relies on OneView Server Profile Templates using HPE Image Streamer OS Deployment plans.



![image](https://user-images.githubusercontent.com/13134334/59421884-abb4a480-8dcf-11e9-953e-8f86187d0dfb.png)


## Environment Variables
It is required to define the OneView credentials and IP address. This can be done directly from the Slack channel using the Hubot commands: 
 
* `find env` - Provides the IP address of the HPE Synergy Composer and the OneView username currently set  
* `set IP <IP>` - Sets the IP address of the HPE Synergy Composer (OneView)
* `set password <password>` - Sets the password of the OneView user with Infrastructure administrator role  
* `set username <name>` - Sets the username of a OneView user with Infrastructure administrator role

![image](https://user-images.githubusercontent.com/13134334/59512244-9ff0dd00-8eb8-11e9-9167-9c767dad787e.png)

## Troubleshooting
Hubot logs can be found in the **Logs** folder of your Hubot (e.g. C:\myhubot\Logs). This is where you usually find all you need for troubleshooting.

> Remember to restart the Hubot Windows service after each modification you make in Hubot in order to activate the change in Slack

## Cleaning up the Hubot help content
If you want to clean up the content of the ``help`` and keep only the ops-related tasks, you can modify **help.coffee** in **\node_modules\hubot-help\src** folder using the ``HUBOT_HELP_HIDDEN_COMMANDS``.   

Any help command you list here will be hidden from the Slack channel:

```
hiddenCommandsPattern = -> HUBOT_HELP_HIDDEN_COMMANDS="ping,adapter,echo,pug me,map me <query>,list assigned roles,the rules,pug bomb N,echo <text>,<user> doesn't have <role> role,<user> has <role> role,what roles do I have,what roles does <user> have,who has <role> role"
hiddenCommands = HUBOT_HELP_HIDDEN_COMMANDS?.split ','
new RegExp "^hubot (?:#{hiddenCommands?.join '|'}) - " if hiddenCommands
```
