## Ansible Oneview with Image Streamer demo

Infrastructure as code demo to automate the deployment of compute resources managed via OneView using Ansible playbooks.
OS deployment and OS configuration are managed by HPE Image Streamer.   

   

## Environment setup

You need to install Ansible and the Ansible Modules for HPE OneView in order to run these playbooks.    
See https://github.com/HewlettPackard/oneview-ansible 

You also need to use the Image Streamer artifact bundle for RHEL 7.3, see https://github.com/HewlettPackard/image-streamer-rhel/tree/master/artifact-bundles   

>The playbooks have been developed and tested with *HPE-RHEL-7.3-2017-04-20.zip*.

## Overall configuration

The playbooks are configured to use the names contained in the `[Synergy]` group defined in the `hosts` file.  
The `hosts` file is located in `/ansible/hosts/`.

```
[Synergy]
RHEL73-webserver[1:2]
```
`[1:2]` means 2 new server profiles will be generated using the name RHEL73-webserver1 and RHEL73-webserver2   

To run the playbook use:
```
ansible-playbook deploy_RHEL73_I3S.yml
```
OneView and Image Streamer connectivity details must be provided in `oneview_config.json`.

## Preparation of the playbook

You need to customize the playbook with your environment details. 

Two variables in the `vars` section of the playbook must be personalized:   
1. `server_template`: this is the name of your server profile template that the playbook will use to generate the server profile(s).   
2. `deployment_plan_name`: this is the Image Streamer deployment plan name that the playbook will use to generate the server OS Volume.    

You also need to customize the `osCustomAttributes` located in the "Creating server profile..." section so that they match with your environment and needs. Those parameters are used to define the OS deployment plan settings (like domain name, hostname, SSH enabled, new user, etc.).

## Actions of the deployment playbook

The Ansible `deploy_RHEL73_I3S.yml` playbook gathers first information about your Synergy environment (Enclosure Group name and URI, management network to be used by the server profile connections) then it creates a server profile using the OS deployment plan attributes provided in the playbook. Once the server profile and OS volume are created, the server is powered on automatically. At the end, the playbook output displays the IPv4 address assigned to each compute module: this can be useful to make a putty connection and show the success of the deployment once the server is running.

## Actions of the decommissioning playbook

The Ansible `remove_RHEL73_I3S.yml` playbook can be used to demonstrate the concept of decommissioning resources and returning them back to the Synergy resource pool. The playbook powers off the compute module(s) and deletes the server profile(s). 

## Output example

This is how Ansible `deploy_RHEL73_I3S.yml` playbook output looks:  

```
[root@ansible ansible]# ansible-playbook deploy_RHEL73_I3S.yml

PLAY [Ansible OneView Synergy playbook to deploy Compute Module(s) using Image Streamer] ***********************************************************************************************

TASK [Gathering facts about Enclosure Group name] **************************************************************************************************************************************
ok: [RHEL73-webserver1 -> localhost]
ok: [RHEL73-webserver2 -> localhost]

TASK [Finding the Enclosure Group name] ************************************************************************************************************************************************
ok: [RHEL73-webserver2]
ok: [RHEL73-webserver1]

TASK [debug] ***************************************************************************************************************************************************************************
ok: [RHEL73-webserver1] => {
    "changed": false,
    "enclosure_groups_name": "EG"
}
ok: [RHEL73-webserver2] => {
    "changed": false,
    "enclosure_groups_name": "EG"
}

TASK [Gathering facts about the Enclosure Group EG] ************************************************************************************************************************************
ok: [RHEL73-webserver1 -> localhost]
ok: [RHEL73-webserver2 -> localhost]

TASK [Finding the Enclosure Group URI] *************************************************************************************************************************************************
ok: [RHEL73-webserver1]
ok: [RHEL73-webserver2]

TASK [debug] ***************************************************************************************************************************************************************************
ok: [RHEL73-webserver1] => {
    "changed": false,
    "enclosure_groups_uri": "/rest/enclosure-groups/efe4f51d-2e2b-4eda-b0fc-1af29a7b19f9"
}
ok: [RHEL73-webserver2] => {
    "changed": false,
    "enclosure_groups_uri": "/rest/enclosure-groups/efe4f51d-2e2b-4eda-b0fc-1af29a7b19f9"
}

TASK [Gathering facts about the management network to be used by the server(s)] ********************************************************************************************************
ok: [RHEL73-webserver1 -> localhost]
ok: [RHEL73-webserver2 -> localhost]

TASK [Finding the management network URI] **********************************************************************************************************************************************
ok: [RHEL73-webserver1]
ok: [RHEL73-webserver2]

TASK [debug] ***************************************************************************************************************************************************************************
ok: [RHEL73-webserver1] => {
    "changed": false,
    "management_ntwrk_uri": "/rest/ethernet-networks/9cba15be-7841-4f45-8de8-9b0c12393fa4"
}
ok: [RHEL73-webserver2] => {
    "changed": false,
    "management_ntwrk_uri": "/rest/ethernet-networks/9cba15be-7841-4f45-8de8-9b0c12393fa4"
}

TASK [Creating server profile(s) with deployment plan RHEL-7.3-personalize-and-NIC-teamings] *******************************************************************************************
changed: [RHEL73-webserver2 -> localhost]
changed: [RHEL73-webserver1 -> localhost]

TASK [Powering on the Compute Module(s)] ***********************************************************************************************************************************************
changed: [RHEL73-webserver2 -> localhost]
changed: [RHEL73-webserver1 -> localhost]

TASK [Displaying IP address(es) assigned to the Compute Module(s)] *********************************************************************************************************************
ok: [RHEL73-webserver2 -> localhost]
ok: [RHEL73-webserver1 -> localhost]

TASK [debug] ***************************************************************************************************************************************************************************
ok: [RHEL73-webserver1] => {
    "changed": false,
    "msg": [
        "192.168.2.141"
    ]
}
ok: [RHEL73-webserver2] => {
    "changed": false,
    "msg": [
        "192.168.2.140"
    ]
}

PLAY RECAP *****************************************************************************************************************************************************************************
RHEL73-webserver1          : ok=13   changed=2    unreachable=0    failed=0
RHEL73-webserver2          : ok=13   changed=2    unreachable=0    failed=0

```

This is how Ansible `remove_RHEL73_I3S.yml` playbook output looks:  

```
[root@ansible ansible]# ansible-playbook remove_RHEL73_I3S.yml

PLAY [Ansible OneView Synergy playbook to remove deployed Compute Module(s) using Image Streamer] **************************************************************************************

TASK [Geting Server Profile(s) information] ********************************************************************************************************************************************
ok: [RHEL73-webserver2 -> localhost]
ok: [RHEL73-webserver1 -> localhost]

TASK [Powering off the Compute Module(s)] **********************************************************************************************************************************************
changed: [RHEL73-webserver1 -> localhost]
changed: [RHEL73-webserver2 -> localhost]

TASK [Deleting the Server Profile(s)] **************************************************************************************************************************************************
changed: [RHEL73-webserver2 -> localhost]
changed: [RHEL73-webserver1 -> localhost]

PLAY RECAP *****************************************************************************************************************************************************************************
RHEL73-webserver1          : ok=3    changed=2    unreachable=0    failed=0
RHEL73-webserver2          : ok=3    changed=2    unreachable=0    failed=0
```

