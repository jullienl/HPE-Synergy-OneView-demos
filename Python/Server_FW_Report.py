from hpOneView.oneview_client import OneViewClient
from pprint import pprint
import csv

config = {
    "ip": "192.168.56.101",
    "api_version": 1200,
    "credentials": {
        "userName": "Administrator",
        "password": "password"
    }
}

oneview_client = OneViewClient(config)
server_hardwares = oneview_client.server_hardware
#server_hardware = server_hardwares.get_by("shortModel", "SY 480 Gen9")
server_hardware = server_hardwares.get_all()

FW_Report = [["Server Name", "Rom Version", "Model", "iLO Address"]]

for serv in server_hardware:
    servername = serv['name']
    RomVersion = serv['romVersion']
    Model = serv['model']
    iLOAddress = serv['mpHostInfo']['mpIpAddresses'][-1]['address']

    ServReporttoAdd = [servername, RomVersion, Model, iLOAddress]
    FW_Report.append(ServReporttoAdd)

with open('FW_Report.csv', 'w') as file:
    writer = csv.writer(file)
    writer.writerows(FW_Report)
