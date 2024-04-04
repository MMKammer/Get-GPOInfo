function Get-GPOInfo {
    <#

    .SYNOPSIS
    This function retrieves all Group Policy Objects and exports their individual reports and a.CSV of their Status settings. 
    Optionally, a .CSV can be created with a list of Group Policy Objects containing one or multiple configuration settings
    .DESCRIPTION
    This function retrieves all Group Policy Objects in a specified domain. Parameter switches can be used individually or in combination to shape the output reports.
    The DomainName and ReportFolder parameters are mandatory.  See the parameter help for more information.

    .PARAMETER DomainName
    This is the Fully Qualified Domain Name (FQDN) of the domain to retrieved GPOs from 
    .PARAMETER ReportFolder
    Folder path for report output
    .PARAMETER GPOSettings
    Optional parameter for settings to find inside GPOs, separated by semicolons
    
    .EXAMPLE
    Get-GPOInfo -DomainName Contoso.com -ReportFolder "C:\GPOs"
    Creates .XML reports in the C:\GPO folder of all Group Policy Objects in the Contoso.com domain, and a .CSV of all GPOs with their Status. 
    .EXAMPLE
    Get-GPOInfo -DomainName Contoso.com -ReportFolder "C:\GPOs" -GPOSettings "CD and DVD; Send unencrypted password to third-party SMB servers"
    Creates .XML reports in the C:\GPO folder of all Group Policy Objects in the Contoso.com domain, and a .CSV of all GPOs with their Status and a
    .CSV of all GPOs with any setting containing the words "CD and DVD" or "Send unencrypted password to third-party SMB servers"
    .INPUTS
    Takes a combination of search filters.
    .OUTPUTS
    Returns .xml reports for every Group Policy Object, and a .CSV or all GPO Status Settings. Optional .CSV of requested settings.
 
    #>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory= $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true,
                    Position=0)]
                    $DomainName,

        [parameter(Mandatory = $true,
                    ValueFromPipeline =$true,
                    ValueFromPipelineByPropertyName =$true,
                    Position=1)]
                    [string]  
                    $ReportFolder, 

        [parameter()]
                [string[]]
                $GPOsettings

    )  #End of parameters



Begin {
    # checks if optional paramater GPOSettings is used, and if so creates an array of entered values
    If ($GPOsettings){
        $splitSettings = $GPOsettings -split ';'
        $normalizedSettings = $splitSettings | ForEach-Object { $_.Trim()}
    } 

} #end of BEGIN
Process {
    # Starts with a check of the existance of the $ReportFolder path, and creates it if it does not exist
    if (-not (Test-Path $ReportFolder)){
        New-Item -ItemType Directory -Path $ReportFolder -Force
      }
      
    $NearestDC = (Get-ADDomainController -Discover -NextClosestSite).Name
    $GPOs = get-GPO -All -Domain $DomainName -Server $NearestDC | Sort-Object Displayname
    $GPOSettingsReport = "$ReportFolder\GPO_Settings.csv"
    $StatusReport = "$ReportFolder\GPO_Status.csv"
    $StatusResults = @()
    $SettingsResults = @()

    Foreach ($GPO in $GPOs){

        Write-Host "Working on "$GPO.DisplayName
        
        $report = Get-gpoReport -Guid $GPO.Id -ReportType xml -Domain $DomainName 
        $report | Export-Clixml -Path $ReportFolder\$($GPO.DisplayName)'.xml'
        
        foreach ($normalSetting in $normalizedSettings){
            if ($Report -match $normalSetting){
                Write-Host $GPO.DisplayName " contains $normalSetting"
                $resultObject = [PSCustomObject]@{
                    GroupPolicyName = $GPO.DisplayName
                    Setting             = $normalSetting
                }
            $SettingsResults += $resultObject
            }
        }
        $name = $gpo.DisplayName
        $gpoStatus = $gpo.GpoStatus
    
        $details = [PSCustomObject]@{
            
            "GPO Name" = $name
            "GPO Status"= $gpoStatus
    
        }
        $StatusResults += $details
    }

} #end of PROCESS

End {
    If ($GPOsettings){
        $SettingsResults | Export-Csv -Path $GPOSettingsReport -NoTypeInformation -Append
    }
    $StatusResults | Export-Csv -Path $StatusReport -NoTypeInformation -Append

} #end of END
} #end of FUNCTION