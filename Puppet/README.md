## Puppet Oneview with Image Streamer demo

Infrastructure as code demo to automate the deployment of compute resources managed via OneView using Puppet manifests.
OS deployment and OS configuration are managed by HPE Image Streamer.   

   
## Environment setup

You need to install the Puppet Module for HPE OneView in order to run these manifests.    
See https://github.com/HewlettPackard/oneview-puppet 

You also need to use the Image Streamer artifact bundle for RHEL 7.3, see https://github.com/HewlettPackard/image-streamer-rhel/tree/master/artifact-bundles   

>The manifests have been developed and tested with *HPE-RHEL-7.3-2017-04-20.zip*.

It is necessary to edit the manifest variables with your own settings (i.e. Profile name, Server Hardware name, Network names, etc.)

### To create a new server profile using the Image Streamer
puppet apply <path>/Server_Profile_Provisioning_with_Image_Streamer.pp

### To remove a server profile using the Image Streamer
puppet apply <path>/Server_Profile_Unprovisioning_with_Image_Streamer.pp
