# OneView API Postman Collection

This repository holds my Postman collection demonstrating use cases for the [OneView REST API](http://h17007.www1.hpe.com/docs/enterprise/servers/oneview4.2/cicf-api/en/index.html). More information about the API can be found on www.hpe.com/info/OneView and https://www.hpe.com/us/en/solutions/developers/composable.html.

I provide a few REST call examples for use with the Postman utility. You will see also how to simplify the REST calls using Javascripts test scripts [[more info here](https://learning.getpostman.com/docs/postman/scripts/test_scripts/)] to generate automatically environment variables like SessionID, X-API-Version but also how to manipulate the JSON body response to generate variables that can be used for the next REST call.

The only Postman environment variable [[more info here](https://learning.getpostman.com/docs/postman/environments_and_globals/variables/)] that needs to be defined is `composer` sets with your OneView FQDN or IP address. 


Postman is a testing framework for REST APIs. The tool can be downloaded from [www.getpostman.com](https://www.getpostman.com/).

To import the collection, first clone this repository, then open the Postman utility and select the Import option. Select the Folder tab from the dialog and drag and drop the cloned repository folder into the target.

[![Run in Postman](https://run.pstmn.io/button.svg)](https://www.getpostman.com/run-collection/cdc462c4e04038b45e7b)
