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
