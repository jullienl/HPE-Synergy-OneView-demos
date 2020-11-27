# Python script to automatically add ESXi host to a vCenter server in kickstart
#
# Requirement:
# - ESXi host must be connected to internet as pip and a missing Python module must be downloaded (requests)
# - vCenter server must be accessible from the ESXi host management network
#
#  Execute the following commands in kickstart:
#
#       # Setting ESXi Firewall to enable httpClient for wget
#       esxcli network firewall ruleset set -e true -r httpClient
#       # Downloading get-pip.py
#       wget -O get-pip.py https://bootstrap.pypa.io/get-pip.py
#       # Installing pip
#       python3 get-pip.py
#       # Installing requests module
#       python3 -m pip install requests
#       # Adding ESXi host to vCenter inventory using this python script Add_host_to_vcenter.py
#       python3 Add_host_to_vcenter.py <ESXi_host_IP> <ESXi_host_root_password> <vcenter_IP> <vcenter_admin_username> <vcenter_admin_username_password>
#       # Setting ESXi Firewall back to disable httpClient
#       esxcli network firewall ruleset set -e false -r httpClient


import urllib3
import requests
import json
import sys


def Add_host_to_vcenter(HostIP, HostPassword, vcenter, vcenteruser, vcenterpassword):
    """
    To run this script use:

    python3 Add_host_to_vcenter.py 192.168.3.191 HPE_invent 192.168.1.35 Administrator@vsphere.local password

    """

    # Suppress InsecureRequestWarning for REST calls
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    # CREATE SESSION
    url = "https://" + vcenter + "/rest/com/vmware/cis/session"

    try:
        response = requests.request(
            "POST", url, verify=False, auth=(vcenteruser, vcenterpassword))
        print("Connected to vcenter " + vcenter)
    except requests.exceptions.RequestException as err:
        print("Error ! Cannot connect to the vcenter server " + vcenter)
        raise SystemExit(err)

    # print(response.text)
    sessionid = (response.json())['value']
    # print("The session ID is " + sessionid)

    # LIST FOLDERS

    url = "https://" + vcenter + "/rest/vcenter/folder"

    headers = {
        'vmware-api-session-id': sessionid

    }

    try:
        response = requests.request(
            "GET", url, headers=headers, verify=False)
    except requests.exceptions.RequestException as err:
        print("Error! Cannot list vcenter folders!")
        raise SystemExit(err)

    # print(response.text)
    resp = (response.json())['value']
    # print(resp)

    # Get HOST folder name
    for item in resp:
        if item['type'] == 'HOST':
            foldername = item['folder']

    print("The Folder name for hosts is " + foldername)

    # CREATE HOST

    url = "https://" + vcenter + "/rest/vcenter/host"

    headers = {
        'vmware-api-session-id': sessionid,
        'Content-Type': 'application/json'

    }

    # print(headers)

    payload = {
        "spec": {
            "folder": foldername,
            "hostname": HostIP,
            "password": HostPassword,
            "thumbprint_verification": "NONE",
            "user_name": "root"
        }
    }

    # print(payload)

    try:
        response = requests.post(url, headers=headers,
                                 verify=False, json=payload)
        print("Host added successfully !")
    except requests.exceptions.RequestException as err:
        print("Error ! Host cannot be added to " + vcenter)
        raise SystemExit(err)


if __name__ == "__main__":
    HostIP = str(sys.argv[1])
    HostPassword = str(sys.argv[2])
    vcenter = str(sys.argv[3])
    vcenteruser = str(sys.argv[4])
    vcenterpassword = str(sys.argv[5])
    Add_host_to_vcenter(HostIP, HostPassword, vcenter,
                        vcenteruser, vcenterpassword)
