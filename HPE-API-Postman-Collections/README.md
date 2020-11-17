# HPE API Postman Collections

This repository holds various Postman collection demonstrating use cases for:
- [HPE OneView REST API](http://h17007.www1.hpe.com/docs/enterprise/servers/oneview4.2/cicf-api/en/index.html)
- [HPE iLO5 RESTful/RedFish API](https://hewlettpackard.github.io/ilo-rest-api-docs/ilo5/)
- [HPE iLO4 RESTful/RedFish API](https://hewlettpackard.github.io/ilo-rest-api-docs/ilo4/)
- [HPE OneView Global Dashboard REST API](http://app.swaggerhub.com/apis/hpe-global-dashboard/hpe-one_view_global_dashboard_rest_api/2)
- [HPE iLO Amplifier Pack REST API](https://hewlettpackard.github.io/iLOAmpPack-Redfish-API-Docs/)
- [HPE Image Streamer REST API](https://techhub.hpe.com/eginfolib/synergy/image_streamer/5.2/i3s-api-ref/en/api-docs/1600/index.html)

More information about HPE APIs can be found on https://www.hpe.com/us/en/solutions/developers/composable.html.

These Postman collections provide many REST and Redfish call examples. Most of these calls use Javascripts test scripts [[more info here](https://learning.getpostman.com/docs/postman/scripts/test_scripts/)] to generate automatically environment variables like *SessionID*, *X-API-Version* that are then used for next calls. They also use JSON body response manipulation to extract values and provide some nice outputs in the Postman *Test Results* console.  

Each collection comes with a Postman [environment](https://learning.postman.com/docs/sending-requests/managing-environments/). An environment is a set of variables [[more info here](https://learning.getpostman.com/docs/postman/environments_and_globals/variables/)] you can use with Postman to set different values like IP addresses, usernames and passwords. 

## Installation

1- Download/install Postman from [www.getpostman.com](https://www.getpostman.com/).

2- Clone this GitHub repository

3- Open the Postman utility 

4- Select the **Import** option to import the collections and variable environments then select the **Folder** tab from the dialog 

5- Drag and drop the cloned **HPE-API-Postman-Collections** repository folder into the target

6- Once the import is completed, select the **Manage Environments** icon to customize each environment with your own IP addresses and credentials. 

7- Select a collection folder then before running any request, select the environment matching with your collection using the environment menu. 

