$PSScriptRoot = $MyInvocation.MyCommand.Path

function Invoke-AzurePSDriveTests([string]$subscriptionName = 'AutomationTeam')
{
    $testResultsFile = Microsoft.PowerShell.Management\Join-Path -Path $PSScriptRoot -ChildPath 'AzurePSDrive.TestResults.xml'

    Write-Host -ForegroundColor Green "Invoking Pester tests"
    # https://www.sapien.com/blog/2016/06/17/how-to-pass-parameters-to-a-pester-test-script/
    Invoke-Pester -Script @{Path = $PSScriptRoot; Parameters = @{subscriptionName = $subscriptionName}} -OutputFormat NUnitXml -OutputFile $testResultsFile

    $testResults += [xml](Get-Content -Raw -Path $testResultsFile)
    $failedTestCount = 0
    $testResults | ForEach-Object { $failedTestCount += ([int]$_.'test-results'.failures); $total += ([int]$_.'test-results'.total) }
   
    if ($failedTestCount -or $total -eq 0)
    {
        throw "$failedTestCount tests failed"
    }
}

function Publish-AzurePSDriveTestResults
{
    param($appVeyorID)

    $testResultsFile = Microsoft.PowerShell.Management\Join-Path -Path $PSScriptRoot -ChildPath 'AzurePSDrive.TestResults.xml'
    Get-ChildItem -Path $testResultsFile | ForEach-Object {
            (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$appVeyorID", "$($_.FullName)")
    }
}

# Ensure all Test dependencies are installed on the machine
function Initialize-TestEnvironment
{
    Install-PackageProvider NuGet -Force

    $dependencyInstalled = (Get-Module -li AzureRM.Resources | ForEach-Object Version) -ge [version]"4.2"
    if (-not $dependencyInstalled)
    {
        Save-Module -Name AzureRM.Resources -MinimumVersion 4.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
    }

    $dependencyInstalled = (Get-Module -li AzureRM.Profile | ForEach-Object Version) -ge [version]"3.2"
    if (-not $dependencyInstalled)
    {
        Save-Module -Name AzureRM.Profile -MinimumVersion 3.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
    }

    $dependencyInstalled = (Get-Module -li AzureRM.Compute | ForEach-Object Version) -ge [version]"3.2"
    if (-not $dependencyInstalled)
    {
        Save-Module -Name AzureRM.Compute -MinimumVersion 3.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
    }

    $dependencyInstalled = (Get-Module -li AzureRM.Network | ForEach-Object Version) -ge [version]"4.2"
    if (-not $dependencyInstalled)
    {
        Save-Module -Name AzureRM.Network -MinimumVersion 4.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
    }

    $dependencyInstalled = (Get-Module -li AzureRM.Storage | ForEach-Object Version) -ge [version]"3.2"
    if (-not $dependencyInstalled)
    {
        Save-Module -Name AzureRM.Storage -MinimumVersion 3.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
    }

    $SHiPSInstalled = Get-Module -li -Name SHiPS 
    if (-not $SHiPSInstalled)
    {
        Save-Module -Name SHiPS -Force -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
    }
    
    $AzurePSDriveInstalled = Get-Module -li -Name AzurePSDrive 
    if (-not $AzurePSDriveInstalled)
    {
        Save-Module -Name AzurePSDrive -Force -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
    }

    Import-Module AzureRM.Resources -Force -Verbose
    Import-Module AzureRM.Profile -Force -Verbose
    Import-Module AzureRM.Compute -Force -Verbose
    Import-Module AzureRM.Network -Force -Verbose
    Import-Module AzureRM.Storage -Force -Verbose
    Import-Module SHiPS -Force -Verbose
    AzureRM.Profile\Disable-AzureRmDataCollection
}

# Login to AzureRM using Service Principal
function Login-AzureRM
{
    # These values are supplied from the environment, such as using Appveyor encryption
    # https://www.appveyor.com/docs/build-configuration/#secure-variables

    $azureAdAppId = $env:azureADAppId
    $password = $env:azurePassword
    $tenantId = $env:azureTenantId

    $secureString = ConvertTo-SecureString -String $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($azureAdAppId, $secureString)

    AzureRM.Profile\Login-AzureRmAccount -ServicePrincipal -Credential $cred -TenantId $tenantId -Verbose -ErrorAction Stop
}
