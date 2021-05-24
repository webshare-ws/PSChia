<#
Plot Collector
 - Author: /u/crux2226
 - https://github.com/webshare-ws/PSChia
 - Donations: xch1043jyeaxqq6ldsl4v53mwffdx8r9s0vlrupy8wyaw0ja5sp8a3lqa7m7g4

This script can be run on a farmer/harvester to collect plots in serial from multiple plotting servers. By pulling the plots from the farmer/harvester side
you can avoid the issue where multiple plotters catch up to each other and try to copy across the network in parallel, causing a bottleneck in transfer speeds
(slowing down both plotters from starting next plot) amonst other performance issues.

The source directories can be mapped network drives, symlinks to shares or even UNC paths, however account this script is run under will need to have permission
on the remote paths.  If a matching account exists on the farmer and plotters, using unc path or symlink will work fine without the need to authenticate
manually.  If the source requires you to authenticate with a different user account, you will need to map it as a network drive first.

In this example, the source folders are symlinks mapped to the output destination on 5 different plotters network shares. 
These are created using below syntax, e.g. :
  mklink /D "C:\chia\plotters\115" "\\192.168.99.115\ChiaOutput"
  
The plotters can be configured to use the same directory for temp and final (or temp2 and final if you're using temp2) - this will cut out the final copy step
during plotting and the plot will just be renamed instead.
#>

$SourceFolders = @('C:\chia\Plotters\115\*.plot', 'C:\chia\Plotters\168\*.plot', 'C:\chia\Plotters\171\*.plot', 'C:\chia\Plotters\172\*.plot', 'C:\chia\Plotters\174\*.plot')

$SleepTime = 30
while($true)
{
    foreach ($folder in $SourceFolders)
    {
        Write-Host Checking for plots in $folder

        # Move .plot files from source to local temp (this will take around 12-18m for a K32 over GigE)
        Move-Item -Path $folder -Destination 'F:\ChiaTemp\'

        # Delay to allow disk cache to finish writing to disk before moving
        Start-Sleep -Seconds 5

        # Move .plot files from local temp to farming folder (this should be almost instant)
        Move-Item -Path 'F:\ChiaTemp\*.plot' -Destination 'F:\ChiaFinal\'
    }
Write-Host Sleeping for $SleepTime Seconds
Start-Sleep -Seconds $SleepTime
}
