<#
Chia Log Parser for Slack
 - Author: /u/crux2226
 - https://github.com/webshare-ws/PSChia
 - Donations: xch1043jyeaxqq6ldsl4v53mwffdx8r9s0vlrupy8wyaw0ja5sp8a3lqa7m7g4

Parses the debug log and reports events to a Slack webhook.  Two different webhooks are used: one for eligible plots and found proofs
and a second for errors and warnings, so you can set your notifications per channel if desired. If you just want one channel use the same webhook for both alert and info.

Instructions:
 SLACK
 - Create two slack channels called ChiaInfo and ChiaAlerts
 - Add a slack app to your workspace (https://api.slack.com/apps?new_app=1  - use the 'from scratch' option, and call it somethign like ChiaBot)
 - Activate the Incoming Webhooks for the app
 - Add two webhooks, one for each of the channels you created
 - Use the webhooks below for $infowebhook and $alertwebhook
 - optional: mute the ChiaInfo channel so it doesn't spam you with notifications
 - optional: add the chia logo on your app

 LOGS
 - Change the log level for your Chia node to 'INFO' 

 OUTPUTS
 - Enable or disable summary/info/warning/error logs using the first 4 variables below (I recommend keeping warning turned off, unless you really want to see it).
 - Update the frequency, in seconds. If you see errors about payload being too large, consider a lower frequency.

 IMPORTANT - Read through this script and understand what it's doing. 
 - Most importantly realise the only outbound connectivity are the rest calls to the slack webhooks you specify
 - Understand that the logs are discarded after being read - if you want to keep the raw logs, change the last step to rename them with a unique name instead.

#>

$plotsummary = $true
$plotinfo = $true
$warninglogs = $false
$errorlogs = $true

$frequency = 300

$infowebhook = 'https://hooks.slack.com/services/xxxxxxxx/yyyyyyyy/abcdefghijklmnopqrstuvwxyzchia'
$alertwebhook = 'https://hooks.slack.com/services/xxxxxxxx/yyyyyyyy/abcdefghijklmnopqrstuvwxyzchia'

$logfilepath = "$env:USERPROFILE\.chia\mainnet\log\debug.log"
$logfiletemp = "$env:USERPROFILE\.chia\mainnet\log\debug.log.temp"

while ($true)
{

if (Test-Path $logfilepath)
{

# Rename the log file to a working file so we can allow new events to write to the log while we process any existing ones.
Rename-Item $logfilepath -NewName $logfiletemp

################################################
##   Step 1:  Read eligible plot messages     ##
##   send the output to slack info webhook    ##
################################################

$eplots = Get-content $logfiletemp | Select-String -Pattern '(?<!\s0\s)plots were eligible for farming'

$Summary = "Plots passed filter"

# If $plotsummary is true, we replace the standard message with a summary including totals and average.
if ($plotsummary)
{
[int]$totalPlots = 0
[int]$totalEligible = 0
[float]$totalTime = 0.0
[int]$totalProofs = 0

foreach ($eplot in $eplots) 
{
$eplot -match "(.*) harvester .*(\d) plots .* farming (.*)\.\.\. Found (\d) .*me: (.*) s\. Total (.*) plots"

$totalEligible += $Matches.2 -as [int]
$totalTime += $Matches.5 -as [float]
$totalProofs += $Matches.4 -as [int]
#setting total to last record plot count
$totalPlots = $Matches.6 -as [int]
}

[float]$avgtime = $totalTime / $eplots.count

$Summary = "*Plots Farming:* $totalPlots \n*Plots Passed Filter:* $totalEligible (since last summary) \n*Average Time:* $avgTime \n*Proofs Found:* $totalProofs"
}

$message = "{""text"": ""$Summary"""

# if $plotinfo is true, we create attachments for each time plots passed filter
if ($plotinfo)
{
$message += ',"attachments": ['

foreach ($eplot in $eplots) 
{
$eplot -match "(.*) harvester .*(\d) plots .* farming (.*)\.\.\. Found (\d) .*me: (.*) s\. Total (.*) plots"
$time = $Matches.5 -as [float]
if($time -gt 5) 
{
$statuscolour = '#C40404'
} 
elseif($time -gt 1) 
{
$statuscolour = '#f0d841'
} 
else 
{
$statuscolour = '#52cf0e'
}
    
if ($Matches.4 -gt 0)
{
$title = ':tada: Proof Found!'
}
else
{
$title = 'Eligible Plots'
}

$attachment = @"
{"title": "$title","title_link": "https://github.com/webshare-ws/PSChia","text": " $($Matches.2) / $($Matches.6)     :tractor:  $($Matches.4)     :timer_clock:   $($Matches.5)","color": "$statuscolour","mrkdwn_in": ["text", "pretext"],},
"@

$message += $attachment
}

$message += ']'
}

$message += '}'

if ($totalPlots -gt 0)
{
Invoke-RestMethod -Uri $infowebhook -Method Post -Body $message
}

###############################################
##   Step 2:  Read WARNING/ERROR messages    ##
##   send the output to slack alert webhook  ##
###############################################

if ($errorlogs)
{
$errlog = Get-content $logfiletemp| Select-String -Pattern ': ERROR'
if ($errlog.Count -gt 0)
{
$summary_error = "$($errlog.Count) errors were encountered since last check:"
$message_error = "{""text"": ""$summary_error"",""attachments"": ["

foreach ($err in $errlog)
{

$attachment = @"
{"text": "$(($err | out-string).replace('"','\"').replace("`n","").replace("'","\'").replace("`r",""))"},
"@
$message_error += $attachment
}
$message_error += ']}'
Invoke-RestMethod -Uri $alertwebhook -Method Post -Body $message_error
}
}


if ($warninglogs)
{
$warnlog = Get-content $logfiletemp| Select-String -Pattern ': WARNING'
if ($warnlog.Count -gt 0)
{
$summary_warning = "$($warnlog.Count) warnings were encountered since last check:"
$message_warning = "{""text"": ""$summary_warning"",""attachments"": ["

foreach ($warn in $warnlog)
{
$attachment = @"
{"text": "$(($warn | out-string).replace('"','\"').replace("`n","").replace("'","\'").replace("`r",""))"},
"@
$message_warning += $attachment
}
$message_warning += ']}'
Invoke-RestMethod -Uri $alertwebhook -Method Post -Body $message_warning
}
}

###############################################
##   Step 3:  Dispose of the temp log file   ##
##   If you want to keep it, change this to  ##
##   move it or store the data in a DB.      ##
###############################################

Remove-Item -Path $logfiletemp

}
else
{
Write-Host $(get-date) No log file to process.
}
Write-Host Sleeping for $frequency seconds
Start-Sleep -Seconds $frequency
}
