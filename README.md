# HPE OneView and Synergy Composer Scripts, Playbooks and Postman collections 

This repository stores a large number of PowerShell scripts, Ansible playbooks and more for HPE Synergy and Proliant Servers.

Information and requirements are listed in the comment section of each scripts/playbooks.

## HPE API Postman Collections

My Postman public workspace is available at https://www.postman.com/jullienl/workspace/lionel-jullien-s-public-workspace 

This workspace contains several Postman collections showing numerous examples of native API requests for various APIs such as:
- [HPE Greenlake for Compute Ops Management API](https://developer.greenlake.hpe.com/docs/greenlake/services/compute-ops/public/openapi/compute-ops-latest/overview/)
- [HPE OneView REST API](https://support.hpe.com/hpesc/public/docDisplay?docId=a00118111en_us&page=GUID-4B5123A2-A300-44BF-A0CC-41E8DC66EA4B.html)
- [HPE iLO RedFish portal](https://servermanagementportal.ext.hpe.com/docs/redfishservices/)
- [HPE OneView Global Dashboard REST API](https://app.swaggerhub.com/apis/hpe-global-dashboard/hpe-one_view_global_dashboard_rest_api/2.1)
- [HPE iLO Amplifier Pack REST API](https://hewlettpackard.github.io/iLOAmpPack-Redfish-API-Docs/)

More information about HPE APIs can be found at https://www.hpe.com/us/en/solutions/developers/composable.html.

These Postman collections provide many examples of REST and Redfish calls. Many of these calls use Javascript to automatically generate environment variables such as *SessionID*, *X-API-Version* which are then used for subsequent calls. To learn more, see [test scripts](https://learning.getpostman.com/docs/postman/scripts/test_scripts/)

These test scripts are also used for manipulation of the JSON response body to extract values and provide nice output in the Postman *Test Results* console.  

Several Postman [environments](https://learning.postman.com/docs/sending-requests/managing-environments/) are provided to set the variables used in the collections.
Make sure to set your own IP addresses and credentials before running a request.
