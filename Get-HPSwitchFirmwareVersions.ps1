<#
.SYNOPSIS
    Get the model number and firmware version for a list of switches.
 
.DESCRIPTION
    This script loops through a list of switches (specified in the script), connects
    to them via SSH, and returns their model numbers and firmware version numbers. 
    It outputs the data in an array. Example output:
 
    Switch     Model  Firmware Version
    ------     -----  ----------------
    172.17.0.1 J8698A K.16.02.0020... 
    172.17.0.3 J8698A K.16.02.0020... 
 
Requirements: 
  * The Posh-SSH module and the Get-SecurePassword.ps1 script.
  * A secure password file containing the switches' password as a secure string. One way to generate
      this file is to use the custom function New-SecurePassFile. You can run it manually once to save 
      the secure password (this must be done on the same computer and by the same user account which
      will be running this script).
 
.OUTPUTS
    [System.Array]
 
.NOTES
    Author: Eric Claus
    Last Modified: 11/25/2017
 
    Thanks to Carlos Perez (aka. darkoperator) for the Posh-SSH module and documentation.
 
.LINK
    https://github.com/darkoperator/Posh-SSH
    http://blog.feldmann.io/powershell/backup-hp-procurve-switches-via-ssh-tftp-and-powershell/
 
.COMPONENT
    Posh-SSH, Get-SecurePassword
#>
 
#Requires -Modules Posh-SSH
 
# Include the Get-SecurePassword function.
$function1 = "$PSScriptRoot\Other\Get-SecurePassword.ps1"
If (Test-Path $function1) {. $function1}
Else {throw "Error: The Get-SecurePassword function was not found."; Exit 1}
 
 
# Create an array of the desired switches' IP addresses.
$switches = @(
    [ipaddress]"172.17.0.1",
    [ipaddress]"172.17.0.3",
    [ipaddress]"172.17.0.4",
    [ipaddress]"172.17.0.5",
    [ipaddress]"172.17.0.6"
    )  
 
# Username of the admin account on the switches, and the secure password file with it's password
$userName = "admin"
$pwdFile = "C:\Scripts\355856924"
# Create a PSCredential object with the username and password above
$credentials = Get-SecurePassword -PwdFile $pwdFile -userName $userName 
 
$myData = @()
 
# Loop through the switches and SSH into each one
foreach ($switch in $switches) {
    # Create a new SSH session to the switch
    $session = New-SSHSession -ComputerName $switch -Credential $credentials -AcceptKey:$True
 
    # Straight SSH sessions will not work with HP's switches. They require an SSH Shell Stream.
    $shellStream = New-SSHShellStream -SSHSession $session
 
    # The first line returned by the switch contains the switch's model number. For
    # example: "HP J9729A 2920-48G-POE+ Switch". Read the first line from the stream
    # and then split the string by spaces and get the second element, the model number.
    $model = $shellStream.ReadLine()
    $model = $model.Split(" ")[1]
 
    # Similarly, the second line returned by the switch contains the firmware version number.
    # For example: "Software revision WB.16.04.0008". Read the line from the stream and then
    # split the string by spaces and get the third element, the firmware version number.
    $version = $shellStream.ReadLine()
    $version = $version.Split(" ")[2]
 
    # Append a PSCustomObject containing the desired information to the $myData array.
    $myData += [PSCustomObject] @{
        "Switch" = $switch
        "Model" = $model
        "Firmware Version" = $version
        }
 
    # Send a space to get past the "Press any key to continue" screen (could be any key)
    $shellStream.WriteLine(" ")
 
    # Finally, logout of the switch and confirm the logout
    $shellStream.WriteLine("logout")
    $shellStream.WriteLine("y")
 
    # Close the SSH session
    Remove-SSHSession -SSHSession $session | Out-Null
}
 
$myData
