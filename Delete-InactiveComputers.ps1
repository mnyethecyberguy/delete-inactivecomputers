<#
    .SYNOPSIS
    Script to query for inactive computer objects in Active Directory and delete them.

    .DESCRIPTION
    Script to query for inactive computer objects in Active Directory and delete them.

    .EXAMPLE

    .NOTES
    ###################################################################################################
    # Author: Michael Nye - https://github.com/mnyethecyberguy                                        #
    # Project: Delete-InactiveComputers - https://github.com/mnyethecyberguy/delete-inactivecomputers #
    # Module Dependencies: ActiveDirectory                                                            #
    # Permission level: Domain Admin                                                                  #
    # Powershell v5 or greater                                                                        #
    ###################################################################################################
#>
# -------------------------------------------------------------------------

# ------------------- IMPORT AD MODULE (IF NEEDED) ------------------------
Import-Module ActiveDirectory

# ------------------- BEGIN USER DEFINED VARIABLES ------------------------
$SCRIPTNAME    	= "Delete-InactiveComputers"
$SCRIPTVERSION 	= "1.0"

# ------------------- END OF USER DEFINED VARIABLES -----------------------


# ------------------- BEGIN MAIN SCRIPT VARIABLES -------------------------
# Establish variable with date/time of script start
$Scriptstart    = Get-Date -Format G

$strCurrDir 	= split-path $MyInvocation.MyCommand.Path
$strLogFolder 	= "$SCRIPTNAME -{0} {1}" -f ($_.name -replace ", ","-"),($Scriptstart -replace ":","-" -replace "/","-")
$strLogPath 	= "$strCurrDir\logs"

# Create log folder for run and logfile name
New-Item -Path $strLogPath -name $strLogFolder -itemtype "directory" -Force > $NULL
$LOGFILE 		= "$strLogPath\$strLogFolder\$SCRIPTNAME.log"

# error action preference must be set to stop for script to function properly, default setting is continue
$ErrorActionPreference = 'stop'

# Set date for inactivity.  Will be compared against pwdLastSet and lastLogonTimeStamp attributes.  Today minus 60 days.
$dateInactive   = (Get-Date).AddDays(-60).ToFileTimeUtc()

# Set list of computer properties to pull
$strCompProperties = 'cn','lastLogonTimestamp','pwdLastSet','whenCreated','whenChanged','sAMAccountName','DNSHostName','distinguishedName'

# Create ldap query.
# Requirements:
#   1) pwdLastSet > 60 days
#   2) and lastLogonTimeStamp > 60 days
$queryLdap      = '(&(pwdLastSet<=' + $dateInactive + ')(lastLogonTimeStamp<=' + $dateInactive + '))'

# Set domain FQDN and search base to query
$strDomainFQDN  = "my.domain.fqdn"
$strOU          = "ou=myou,dc=mydomain,dc=com"

# setup output file to export results
$csvInactivesLog = "$strLogPath\$strLogFolder\$strDomainFQDN.csv"

# setup array to store inactive computers found in the domain
$arrInactiveComputers = @()

$countSuccess   = 0


# ------------------- END MAIN SCRIPT VARIABLES ---------------------------


# ------------------- DEFINE FUNCTIONS - DO NOT MODIFY --------------------

Function Writelog ($LogText)
{
	$date = Get-Date -format G
	
    write-host "$date $LogText"
	write-host ""
	
    "$date $LogText" >> $LOGFILE
	"" >> $LOGFILE
}

Function genReports
{
	if ($arrInactiveComputers.Count -gt 0)
	{
		$arrInactiveComputers | Export-CSV -NoTypeInformation $csvInactivesLog
	}
}

Function BeginScript () {
    Writelog "-------------------------------------------------------------------------------------"
    Writelog "**** BEGIN SCRIPT AT $Scriptstart ****"
    Writelog "**** Script Name:     $SCRIPTNAME"
    Writelog "**** Script Version:  $SCRIPTVERSION"
    Writelog "-------------------------------------------------------------------------------------"

    $error.clear()
}

Function EndScript () {
	Writelog "-------------------------------------------------------------------------------------"
    Writelog "**** SCRIPT RESULTS ****"
    Writelog "**** Successfully Deleted $countSuccess Computer Objects from $strDomainFQDN"
    Writelog "-------------------------------------------------------------------------------------"

    $Scriptfinish = Get-Date -Format G
	$span = New-TimeSpan $Scriptstart $Scriptfinish
	
  	Writelog "-------------------------------------------------------------------------------------"
  	Writelog "**** $SCRIPTNAME script COMPLETED at $Scriptfinish ****"
	Writelog $("**** Total Runtime: {0:00} hours, {1:00} minutes, and {2:00} seconds ****" -f $span.Hours,$span.Minutes,$span.Seconds)
	Writelog "-------------------------------------------------------------------------------------"
}

# ------------------- END OF FUNCTION DEFINITIONS -------------------------


# ------------------- SCRIPT MAIN - DO NOT MODIFY -------------------------

BeginScript

# Collect Inactive Computers
Try
{
    $arrTmpInactiveComputers = Get-ADComputer -Server $strDomainFQDN -SearchBase $strOU -LDAPFilter $queryLdap -Properties $strCompProperties | Select-Object $strCompProperties
    Writelog "**** Successfully collected inactive computers for the $strDomainFQDN domain - (count: $($arrTmpInactiveComputers.Count))"
    Writelog "-------------------------------------------------------------------------------------"

    
    ForEach ($computer in $arrTmpInactiveComputers)
    {
        $arrInactiveComputers += $computer
        
        $computer | Remove-ADObject -Server $strDomainFQDN -Recursive -Confirm:$false

        Writelog "**** Deleted $($computer.sAMAccountname)"

        $countSuccess++
    }
}
Catch
{
    Writelog "**** No inactive computers found for the domain $strDomainFQDN"
    Writelog "-------------------------------------------------------------------------------------"
}

genReports

# ------------------- END OF SCRIPT MAIN ----------------------------------


# ------------------- CLEANUP ---------------------------------------------


# ------------------- SCRIPT END ------------------------------------------
$error.clear()

EndScript
