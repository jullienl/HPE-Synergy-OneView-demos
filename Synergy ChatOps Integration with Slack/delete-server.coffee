# Description:
#   Unprovision a server 
#
# Commands:
#   `delete <name>` - Turns off and unprovisions a server 

# Require the edge module we installed
edge = require("edge")

# Build the PowerShell that will execute
executePowerShell = edge.func('ps', -> ###
  # Dot source the function
  . .\scripts\delete-server.ps1

  # Edge.js passes an object to PowerShell as a variable - $inputFromJS
  # This object is built in CoffeeScript on line 28 below
  delete-server -name $inputFromJS.name
###
)

module.exports = (robot) ->
  # Capture the user message using a regex capture
  # to reset the Labs teamnumber
  robot.respond /delete (.*)$/i, (msg) ->
    # Set the teamnumber to a varaible
    msg.send "I hope my dear master you know what you are doing..."
    name = msg.match[1]
    console.log("Server to undeploy is " + name) 
    
    # Build an object to send to PowerShell
    psObject = {
      name: name
    }

    # Build the PowerShell callback
    callPowerShell = (psObject, msg) ->
      executePowerShell psObject, (error,result) ->
        # If there are any errors that come from the CoffeeScript command
        if error
          msg.send ":fire: An error was thrown in Node.js/CoffeeScript"
          msg.send error
        else
          # Capture the PowerShell outpout and convert the
          # JSON that the function returned into a CoffeeScript object
          result = JSON.parse result[0]
          
          # Output the results into the Hubot log file so
          # we can see what happened - useful for troubleshooting
          console.log result
          
          # Check in our object if the command was a success
          # (checks the JSON returned from PowerShell)
          # If there is a success, prepend a check mark emoji
          # to the output from PowerShell.

          # Messages for Server Profile deletion
          if result.success is true
            # Build a string to send back to the channel and
            # include the output (this comes from the JSON output)
            msg.send ":heavy_check_mark: #{result.output}"
          # If there is a failure, prepend a warning emoji to
          # the output from PowerShell.
          else
            # Build a string to send back to the channel and
            #include the output (this comes from the JSON output)
            msg.send ":warning: #{result.output}"




    # Call PowerShell function
    callPowerShell psObject, msg
