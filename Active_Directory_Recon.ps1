<#

.SYNOPSIS

    Active_Directory_Recon is a tool which gathers information about the Active Directory and generates a report which can provide a holistic picture of the current state of the target AD environment.

.DESCRIPTION

    Active_Directory_Recon extracts and combines various artifacts from an AD environment. The generated report includes  
    summary views and metrics to facilitate analysis for security professionals, auditors, and administrators.  
    It can also be a valuable tool for penetration testers.  

    The tool supports both ADWS and LDAP methods and can collect information on:  
    - Domains, Trusts, and Sites  
    - Domain Controllers and Password Policies  
    - Users, Groups, and Organizational Units  
    - Group Policies, ACLs, and DNS records  
    - Service accounts, Printers, and Computers  

.NOTES

    Execution Policy Instructions:  
    If script execution is restricted, use one of the following:  

    1️⃣ Run PowerShell as Administrator and execute:  
        PS > Set-ExecutionPolicy Bypass -Scope Process -Force  

    2️⃣ Or run the script with:  
        powershell.exe -ExecutionPolicy Bypass -File .\Active_Directory_Recon.ps1  

    3️⃣ If already in PowerShell:  
        PS > $Env:PSExecutionPolicyPreference = 'Bypass'  

.PARAMETER Method
	Which method to use; ADWS (default), LDAP

.PARAMETER DomainController
	Domain Controller IP Address or Domain FQDN.

.PARAMETER Credential
	Domain Credentials.

.PARAMETER GenExcel
	Path for Active_Directory_Recon output folder containing the CSV files to generate the Active_Directory_Recon-Report.xlsx. Use it to generate the Active_Directory_Recon-Report.xlsx when Microsoft Excel is not installed on the host used to run Active_Directory_Recon.

.PARAMETER OutputDir
	Path for Active_Directory_Recon output folder to save the files and the Active_Directory_Recon-Report.xlsx. (The folder specified will be created if it doesn't exist)

.PARAMETER Collect
    Which modules to run; Comma separated; e.g Forest,Domain (Default all except Kerberoast, DomainAccountsusedforServiceLogon)
    Valid values include: Forest, Domain, Trusts, Sites, Subnets, SchemaHistory, PasswordPolicy, FineGrainedPasswordPolicy, DomainControllers, Users, UserSPNs, PasswordAttributes, Groups, GroupChanges, GroupMembers, OUs, GPOs, gPLinks, DNSZones, DNSRecords, Printers, Computers, ComputerSPNs, LAPS, BitLocker, ACLs, GPOReport, Kerberoast, DomainAccountsusedforServiceLogon.

.PARAMETER OutputType
    Output Type; Comma seperated; e.g STDOUT,CSV,XML,JSON,HTML,Excel (Default STDOUT with -Collect parameter, else CSV and Excel).
    Valid values include: STDOUT, CSV, XML, JSON, HTML, Excel, All (excludes STDOUT).

.PARAMETER DormantTimeSpan
    Timespan for Dormant accounts. (Default 90 days)

.PARAMETER PassMaxAge
    Maximum machine account password age. (Default 30 days)

.PARAMETER PageSize
    The PageSize to set for the LDAP searcher object.

.PARAMETER Threads
    The number of threads to use during processing objects. (Default 10)

.PARAMETER OnlyEnabled
    Only collect details for enabled objects. (Default $false)

.PARAMETER Log
    Create Active_Directory_Recon Log using Start-Transcript

#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false, HelpMessage = "Which method to use; ADWS (default), LDAP")]
    [ValidateSet('ADWS', 'LDAP')]
    [string] $Method = 'ADWS',

    [Parameter(Mandatory = $false, HelpMessage = "Domain Controller IP Address or Domain FQDN.")]
    [string] $DomainController = '',

    [Parameter(Mandatory = $false, HelpMessage = "Domain Credentials.")]
    [Management.Automation.PSCredential] $Credential = [Management.Automation.PSCredential]::Empty,

    [Parameter(Mandatory = $false, HelpMessage = "Path for ADRecon output folder containing the CSV files to generate the ADRecon-Report.xlsx. Use it to generate the ADRecon-Report.xlsx when Microsoft Excel is not installed on the host used to run ADRecon.")]
    [string] $GenExcel,

    [Parameter(Mandatory = $false, HelpMessage = "Path for ADRecon output folder to save the CSV/XML/JSON/HTML files and the ADRecon-Report.xlsx. (The folder specified will be created if it doesn't exist)")]
    [string] $OutputDir,

    [Parameter(Mandatory = $false, HelpMessage = "Which modules to run; Comma separated; e.g Forest,Domain (Default all except Kerberoast, DomainAccountsusedforServiceLogon)")]
    [ValidateSet('Forest', 'Domain', 'Trusts', 'Sites', 'Subnets', 'SchemaHistory', 'PasswordPolicy', 'FineGrainedPasswordPolicy', 'DomainControllers', 'Users', 'UserSPNs', 'PasswordAttributes', 'Groups', 'GroupChanges', 'GroupMembers', 'OUs', 'GPOs', 'gPLinks', 'DNSZones', 'DNSRecords', 'Printers', 'Computers', 'ComputerSPNs', 'LAPS', 'BitLocker', 'ACLs', 'GPOReport', 'Kerberoast', 'DomainAccountsusedforServiceLogon', 'Default')]
    [array] $Collect = 'Default',

    [Parameter(Mandatory = $false, HelpMessage = "Output type; Comma seperated; e.g STDOUT,CSV,XML,JSON,HTML,Excel (Default STDOUT with -Collect parameter, else CSV and Excel)")]
    [ValidateSet('STDOUT', 'CSV', 'XML', 'JSON', 'EXCEL', 'HTML', 'All', 'Default')]
    [array] $OutputType = 'Default',

    [Parameter(Mandatory = $false, HelpMessage = "Timespan for Dormant accounts. Default 90 days")]
    [ValidateRange(1,1000)]
    [int] $DormantTimeSpan = 90,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum machine account password age. Default 30 days")]
    [ValidateRange(1,1000)]
    [int] $PassMaxAge = 30,

    [Parameter(Mandatory = $false, HelpMessage = "The PageSize to set for the LDAP searcher object. Default 200")]
    [ValidateRange(1,10000)]
    [int] $PageSize = 200,

    [Parameter(Mandatory = $false, HelpMessage = "The number of threads to use during processing of objects. Default 10")]
    [ValidateRange(1,100)]
    [int] $Threads = 10,

    [Parameter(Mandatory = $false, HelpMessage = "Only collect details for enabled objects. Default `$false")]
    [bool] $OnlyEnabled = $false,

    [Parameter(Mandatory = $false, HelpMessage = "Create ADRecon Log using Start-Transcript.")]
    [switch] $Log
)
Try {
    $ADDomain = Get-ADDomain
}
Catch {
    Write-Warning "[Get-ADRDomain] Error getting Domain Context"
    Write-Verbose "[EXCEPTION] $($_.Exception.Message)"
    Return $null
}

If ($ADDomain) {
    $DomainObj = @()

    $FLAD = @{
        0 = "Windows2000"
        1 = "Windows2003/Interim"
        2 = "Windows2003"
        3 = "Windows2008"
        4 = "Windows2008R2"
        5 = "Windows2012"
        6 = "Windows2012R2"
        7 = "Windows2016"
    }

    $DomainMode = $FLAD[[convert]::ToInt32($ADDomain.DomainMode)] + "Domain"
    Remove-Variable FLAD

    If (-Not $DomainMode) {
        $DomainMode = $ADDomain.DomainMode
    }

    $ObjValues = @("Name", $ADDomain.DNSRoot, "NetBIOS", $ADDomain.NetBIOSName, "Functional Level", $DomainMode, "DomainSID", $ADDomain.DomainSID.Value)

    For ($i = 0; $i -lt $($ObjValues.Count); $i++) {
        $Obj = New-Object PSObject
        $Obj | Add-Member -MemberType NoteProperty -Name "Category" -Value $ObjValues[$i]
        $Obj | Add-Member -MemberType NoteProperty -Name "Value" -Value $ObjValues[$i+1]
        $i++
        $DomainObj += $Obj
    }
}
Try {
    $Trusts = Get-ADTrust -Filter *
}
Catch {
    Write-Warning "[Get-ADTrusts] Error getting Trusts"
    Write-Verbose "[EXCEPTION] $($_.Exception.Message)"
    Return $null
}

If ($Trusts) {
    $TrustObj = @()
    ForEach ($Trust in $Trusts) {
        $Obj = New-Object PSObject
        $Obj | Add-Member -MemberType NoteProperty -Name "SourceDomain" -Value $Trust.SourceName
        $Obj | Add-Member -MemberType NoteProperty -Name "TargetDomain" -Value $Trust.TargetName
        $Obj | Add-Member -MemberType NoteProperty -Name "TrustType" -Value $Trust.TrustType
        $Obj | Add-Member -MemberType NoteProperty -Name "TrustDirection" -Value $Trust.Direction
        $Obj | Add-Member -MemberType NoteProperty -Name "TrustAttributes" -Value $Trust.TrustAttributes
        $TrustObj += $Obj
    }
}

$ADDomainControllers = Get-ADDomainController -Filter *

$DomainControllerObj = @()
ForEach ($DC in $ADDomainControllers) {
    $Obj = New-Object PSObject
    $Obj | Add-Member -MemberType NoteProperty -Name "HostName" -Value $DC.HostName
    $Obj | Add-Member -MemberType NoteProperty -Name "IPv4Address" -Value $DC.IPv4Address
    $Obj | Add-Member -MemberType NoteProperty -Name "Site" -Value $DC.Site
    $Obj | Add-Member -MemberType NoteProperty -Name "IsGlobalCatalog" -Value $DC.IsGlobalCatalog
    $Obj | Add-Member -MemberType NoteProperty -Name "IsReadOnly" -Value $DC.IsReadOnly
    $Obj | Add-Member -MemberType NoteProperty -Name "OperationMasterRoles" -Value ($DC.OperationMasterRoles -join ", ")
    $DomainControllerObj += $Obj
}

# Simplified extraction logic (actual implementation may involve C#-style embedded logic or PInvoke)
$DCSMBObj = New-Object PSObject
$DCSMBObj | Add-Member -MemberType NoteProperty -Name "SMB1(NT LM 0.12)" -Value $null
$DCSMBObj | Add-Member -MemberType NoteProperty -Name "SMB2(0x0202)" -Value $null
$DCSMBObj | Add-Member -MemberType NoteProperty -Name "SMB3(0x0300)" -Value $null
$DCSMBObj | Add-Member -MemberType NoteProperty -Name "SMB Signing" -Value $null

$PasswordPolicy = Get-ADDefaultDomainPasswordPolicy

$PolicyObj = @()
$PolicyObj += New-Object PSObject -Property @{
    "MinPasswordLength" = $PasswordPolicy.MinPasswordLength
    "PasswordHistoryCount" = $PasswordPolicy.PasswordHistoryCount
    "MaxPasswordAge" = $PasswordPolicy.MaxPasswordAge
    "MinPasswordAge" = $PasswordPolicy.MinPasswordAge
    "ComplexityEnabled" = $PasswordPolicy.ComplexityEnabled
    "ReversibleEncryptionEnabled" = $PasswordPolicy.ReversibleEncryptionEnabled
}

$FGPolicies = Get-ADFineGrainedPasswordPolicy -Filter *

$FGPolicyObj = @()
ForEach ($Policy in $FGPolicies) {
    $Obj = New-Object PSObject
    $Obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $Policy.Name
    $Obj | Add-Member -MemberType NoteProperty -Name "Precedence" -Value $Policy.Precedence
    $Obj | Add-Member -MemberType NoteProperty -Name "MinPasswordLength" -Value $Policy.MinPasswordLength
    $Obj | Add-Member -MemberType NoteProperty -Name "PasswordHistoryCount" -Value $Policy.PasswordHistoryCount
    $Obj | Add-Member -MemberType NoteProperty -Name "MaxPasswordAge" -Value $Policy.MaxPasswordAge
    $Obj | Add-Member -MemberType NoteProperty -Name "MinPasswordAge" -Value $Policy.MinPasswordAge
    $Obj | Add-Member -MemberType NoteProperty -Name "ComplexityEnabled" -Value $Policy.ComplexityEnabled
    $FGPolicyObj += $Obj
}


$ADUsers = @( 
    Get-ADUser -Filter * -ResultPageSize $PageSize -Properties `
        AccountExpirationDate, accountExpires, AccountNotDelegated, AdminCount, AllowReversiblePasswordEncryption, `
        CannotChangePassword, CanonicalName, Company, Department, Description, DistinguishedName, `
        DoesNotRequirePreAuth, Enabled, givenName, homeDirectory, Info, LastLogonDate, lastLogonTimestamp, `
        LockedOut, LogonWorkstations, mail, Manager, memberOf, middleName, mobile, `
        'msDS-AllowedToDelegateTo', 'msDS-SupportedEncryptionTypes', Name, PasswordExpired, PasswordLastSet, `
        PasswordNeverExpires, PasswordNotRequired, primaryGroupID, profilePath, pwdLastSet, SamAccountName, `
        ScriptPath, servicePrincipalName, SID, SIDHistory, SmartcardLogonRequired, sn, Title, `
        TrustedForDelegation, TrustedToAuthForDelegation, UseDESKeyOnly, UserAccountControl, whenChanged, whenCreated
)


$ADGroups = Get-ADGroup -Filter *

$GroupObj = @()
foreach ($Group in $ADGroups) {
    $Obj = New-Object PSObject
    $Obj | Add-Member -MemberType NoteProperty -Name "GroupName" -Value $Group.Name
    $Obj | Add-Member -MemberType NoteProperty -Name "DistinguishedName" -Value $Group.DistinguishedName
    $Obj | Add-Member -MemberType NoteProperty -Name "GroupScope" -Value $Group.GroupScope
    $Obj | Add-Member -MemberType NoteProperty -Name "Description" -Value $Group.Description
    $GroupObj += $Obj
}

$GroupMembers = @()
foreach ($Group in $ADGroups) {
    $Members = Get-ADGroupMember -Identity $Group.DistinguishedName -ErrorAction SilentlyContinue
    foreach ($Member in $Members) {
        $MemberObj = New-Object PSObject
        $MemberObj | Add-Member -MemberType NoteProperty -Name "Group" -Value $Group.Name
        $MemberObj | Add-Member -MemberType NoteProperty -Name "Member" -Value $Member.SamAccountName
        $MemberObj | Add-Member -MemberType NoteProperty -Name "MemberType" -Value $Member.objectClass
        $GroupMembers += $MemberObj
    }
}

$ADOUs = @( Get-ADOrganizationalUnit -Filter * -Properties DistinguishedName, Description, Name, whenCreated, whenChanged )

If ($ADOUs) {
    Write-Verbose "[*] Total OUs: $([ADRecon.ADWSClass]::ObjectCount($ADOUs))"
    $OUObj = [ADRecon.ADWSClass]::OUParser($ADOUs, $Threads)
    Remove-Variable ADOUs
}

$ADGPOs = @( Get-GPO -All )

If ($ADGPOs) {
    Write-Verbose "[*] Total GPOs: $([ADRecon.ADWSClass]::ObjectCount($ADGPOs))"
    $GPOObj = [ADRecon.ADWSClass]::GPOParser($ADGPOs, $Threads)
    Remove-Variable ADGPOs
}

$ADSOMs = @( Get-ADOrganizationalUnit -Filter * -Properties gPLink )

If ($ADSOMs) {
    Write-Verbose "[*] Total gPLinks: $([ADRecon.ADWSClass]::ObjectCount($ADSOMs))"
    $gPLinkObj = [ADRecon.ADWSClass]::SOMParser($ADGPOs, $ADSOMs, $Threads)
    Remove-Variable ADSOMs
}

$ADFileName = -join($ReportPath,'\','DNSZones.csv')
Get-ADRExcelWorkbook -Name "DNS Zones"

$ADFileName = -join($ReportPath,'\','DNSRecords.csv')
Get-ADRExcelWorkbook -Name "DNS Records"

$ADPrinters = @( Get-ADObject -LDAPFilter "(objectCategory=printQueue)" -Properties Name, ServerName, Location, ShareName )

If ($ADPrinters) {
    Write-Verbose "[*] Total Printers: $([ADRecon.ADWSClass]::ObjectCount($ADPrinters))"
    $PrinterObj = [ADRecon.ADWSClass]::PrinterParser($ADPrinters, $Threads)
    Remove-Variable ADPrinters
}

$ADComputers = @( Get-ADComputer -Filter * -Properties DNSHostName, OperatingSystem, OperatingSystemServicePack, OperatingSystemVersion, IPv4Address, LastLogonDate, PasswordLastSet )

If ($ADComputers) {
    Write-Verbose "[*] Total Computers: $([ADRecon.ADWSClass]::ObjectCount($ADComputers))"
    $ComputerObj = [ADRecon.ADWSClass]::ComputerParser($ADComputers, $StartDate, $DormantDays, $PasswordMaxAge, $Threads)
    Remove-Variable ADComputers
}

$ADUsers = @( 
    Get-ADObject -LDAPFilter "(&(samAccountType=805306368)(servicePrincipalName=*)(!userAccountControl:1.2.840.113556.1.4.803:=2))" `
    -Properties Name, Description, memberOf, sAMAccountName, servicePrincipalName, primaryGroupID, pwdLastSet, userAccountControl
)

If ($ADUsers) {
    Write-Verbose "[*] Service Accounts Found: $($ADUsers.Count)"
}
