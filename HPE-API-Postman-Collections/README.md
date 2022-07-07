# HPE API Postman Collections


My Postman public workspace is available at https://www.postman.com/jullienl/workspace/lionel-jullien-s-public-workspace 

This workspace contains various Postman collections demonstrating use cases:
- [HPE Greenlake for Compute Ops Management API](https://developer.greenlake.hpe.com/docs/greenlake/services/compute-ops/public/openapi/compute-ops-latest/overview/)
- [HPE OneView REST API](http://h17007.www1.hpe.com/docs/enterprise/servers/oneview4.2/cicf-api/en/index.html)
- [HPE iLO5 RESTful/RedFish API](https://hewlettpackard.github.io/ilo-rest-api-docs/ilo5/)
- [HPE iLO4 RESTful/RedFish API](https://hewlettpackard.github.io/ilo-rest-api-docs/ilo4/)
- [HPE OneView Global Dashboard REST API](http://app.swaggerhub.com/apis/hpe-global-dashboard/hpe-one_view_global_dashboard_rest_api/2)
- [HPE iLO Amplifier Pack REST API](https://hewlettpackard.github.io/iLOAmpPack-Redfish-API-Docs/)
- [HPE Image Streamer REST API](https://techhub.hpe.com/eginfolib/synergy/image_streamer/5.2/i3s-api-ref/en/api-docs/1600/index.html)

More information about HPE APIs can be found at https://www.hpe.com/us/en/solutions/developers/composable.html.

These Postman collections provide many examples of REST and Redfish calls. Many of these calls use Javascript to automatically generate environment variables such as *SessionID*, *X-API-Version* which are then used for subsequent calls. To learn more, see [test scripts](https://learning.getpostman.com/docs/postman/scripts/test_scripts/)

These test scripts are also used for manipulation of the JSON response body to extract values and provide nice output in the Postman *Test Results* console.  

Several Postman [environments](https://learning.postman.com/docs/sending-requests/managing-environments/) are provided to set the variables used in the collections.
Make sure to set your own IP addresses and credentials before running a request.
