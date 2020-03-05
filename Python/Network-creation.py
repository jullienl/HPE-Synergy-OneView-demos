from hpOneView.oneview_client import OneViewClient
from pprint import pprint

config = {
    "ip": "192.168.56.101",
    "api_version": 1200,
    "credentials": {
        "userName": "Administrator",
        "password": "password"
    }
}

oneview_client = OneViewClient(config)

ethernet_networks = oneview_client.ethernet_networks
network_sets = oneview_client.network_sets


# Create Ethernet network

options_ethernet = {
    "name": "RHEL Prod",
    "vlanId": 50,
    "ethernetNetworkType": "Tagged",
    "purpose": "General",
    "smartLink": False,
    "privateNetwork": False,
    "connectionTemplateUri": None,
}

ethernet_network = ethernet_networks.create(options_ethernet)

print("Created ethernet-networks successfully.\n  uri = '%s' " %
      (ethernet_network.data['uri']))


# Adding network to Logical Interconnect Uplink Set

uplink_sets = oneview_client.uplink_sets

logical_interconnect_uri = oneview_client.logical_interconnects.get_all()[
    0]['uri']

#print("LI uri = '%s' " % (logical_interconnect_uri))

ethernet_network_uri = ethernet_network.data['uri']

#print("Enet uri = '%s' " % (ethernet_network_uri))

ethernet_network_name = options_ethernet['name']

#print("Enet uri = '%s' " % (ethernet_network_name))

uplink_set = uplink_sets.get_by_name("US-Prod")

#print("\nAdd ethernet network to the uplink set")

uplink_added_ethernet = uplink_set.add_ethernet_networks(
    ethernet_network_name)

print("The uplink set with name = '{name}' have now the networks:\n {networkUris}".format(
    **uplink_added_ethernet))


# Adding new network to Network Set

network_set = network_sets.get_by_name("Prod")
# print("Found network set by name: '%s'.\n  uri = '%s'" %
#       (network_set.data['name'], network_set.data['uri']))


networkset_networkUris = (network_set.data)['networkUris']

new_networkset_networkUris = networkset_networkUris + [ethernet_network_uri]

network_set_update = {'networkUris': new_networkset_networkUris}

network_set = network_set.update(network_set_update)

print("Updated network set '%s' successfully.\n" %
      (network_set.data['name']))
