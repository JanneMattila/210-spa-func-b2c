Param (
    [Parameter(HelpMessage="Deployment environment name")] 
    [string] $EnvironmentName = "local",
    
    [Parameter(HelpMessage="Flag to indicate if AzureAD applications reply urls should be updated")] 
    [switch] $UpdateReplyUrl,

    [Parameter(HelpMessage="SPA Reader address root uri")] 
    [string] $SPAReaderUri = "https://localhost:44387/",
    
    [Parameter(HelpMessage="SPA Writer address root uri")] 
    [string] $SPAWriterUri = "https://localhost:44388/"
)

$ErrorActionPreference = "Stop"

# Use existing Azure context to login to Azure AD
$context = Get-AzContext
$accountId = $context.Account.Id
$tenant = $context.Tenant.TenantId
$scope = "https://graph.windows.net" # Azure AD Graph API
$dialog = [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never

$azureSession = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $tenant, $null, $dialog, $null, $scope)

# Azure AD Graph API token
$accessToken = $azureSession.AccessToken

$aadInstalledModule = Get-Module -Name "AzureAD" -ListAvailable
if ($null -eq $aadInstalledModule)
{
    Install-Module AzureAD -Scope CurrentUser -Force
}
else
{
    Import-Module AzureAD
}

Connect-AzureAD -AadAccessToken $accessToken -AccountId $accountId -TenantId $tenant | Out-Null

$apiAppName = "SPA-FUNC API $EnvironmentName"
$spaReaderAppName = "SPA-FUNC Sales Reader $EnvironmentName"
$spaWriterAppName = "SPA-FUNC Sales Writer $EnvironmentName"

$apiApp = Get-AzureADApplication -SearchString $apiAppName
$spaReaderApp = Get-AzureADApplication -SearchString $spaReaderAppName
$spaWriterApp = Get-AzureADApplication -SearchString $spaWriterAppName

if ($null -ne $apiApp)
{
    # Applications have been already created
    Write-Host "Applications have been already created"

    if ($UpdateReplyUrl)
    {
        Set-AzureADApplication -ObjectId $spaReaderApp.ObjectId -ReplyUrls $SPAReaderUri
        Set-AzureADApplication -ObjectId $spaWriterApp.ObjectId -ReplyUrls $SPAWriterUri
    }
}
else
{
    ######################
    # Setup functions app:
    # - Expose API "Sales.Read"
    # - Expose API "Sales.ReadWrite"
    $permissions = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.OAuth2Permission]

    # Known identifiers of Microsoft Graph API
    $microsoftGraphAPI = "00000003-0000-0000-c000-000000000000"
    $userRead = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # "User.Read"

    # Custom identifiers for our APIs
    $permissionSalesRead = "d2dc4339-3161-4d78-a579-8b50f4c4da39" # "Sales.Read"
    $permissionSalesReadWrite = "39579f07-da63-4735-850d-f802b0d08057" # "Sales.ReadWrite"

    $readPermission = New-Object Microsoft.Open.AzureAD.Model.OAuth2Permission
    $readPermission.Id = $permissionSalesRead
    $readPermission.Value = "Sales.Read"
    $readPermission.Type = "User"
    $readPermission.AdminConsentDisplayName = "Admin consent for granting read access to sales data"
    $readPermission.AdminConsentDescription = "Admin consent for granting read access to sales data"
    $readPermission.UserConsentDisplayName = "Read access to sales data"
    $readPermission.UserConsentDescription = "Read access to sales data"
    $permissions.Add($readPermission)

    $readWritePermission = New-Object Microsoft.Open.AzureAD.Model.OAuth2Permission
    $readWritePermission.Id = $permissionSalesReadWrite
    $readWritePermission.Value = "Sales.ReadWrite"
    $readWritePermission.Type = "User"
    $readWritePermission.AdminConsentDisplayName = "Admin consent for granting read-write access to sales data"
    $readWritePermission.AdminConsentDescription = "Admin consent for granting read-write access to sales data"
    $readWritePermission.UserConsentDisplayName = "Read-write access to sales data"
    $readWritePermission.UserConsentDescription = "Read-write access to sales data"
    $permissions.Add($readWritePermission)

    $apiApp = New-AzureADApplication -DisplayName $apiAppName `
        -IdentifierUris "api://spa-func.$EnvironmentName" `
        -PublicClient $false `
        -Oauth2Permissions $permissions
    $apiApp

    $apiSpn = New-AzureADServicePrincipal -AppId $apiApp.AppId

    ###########################
    # Setup SPASalesReader app:
    $readerAccesses = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]

    # API permission for "User.Read" in Microsoft Graph
    $readerUserRead = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
    $readerUserRead.Id = $userRead # "User.Read"
    $readerUserRead.Type = "Scope"

    $readerGraph = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $readerGraph.ResourceAppId = $microsoftGraphAPI # "Microsoft Graph API"
    $readerGraph.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]
    $readerGraph.ResourceAccess.Add($readerUserRead)

    # API permission for "Sales.Read" in SPA-FUNC
    $readerSalesRead = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
    $readerSalesRead.Id = $readPermission.Id # "Sales.Read"
    $readerSalesRead.Type = "Scope"

    $readerApi = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $readerApi.ResourceAppId = $apiApp.AppId # "SPA FUNC"
    $readerApi.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]
    $readerApi.ResourceAccess.Add($readerSalesRead)

    # Add required accesses
    $readerAccesses.Add($readerGraph)
    $readerAccesses.Add($readerApi)

    $spaReaderApp = New-AzureADApplication -DisplayName $spaReaderAppName `
        -Oauth2AllowImplicitFlow $true `
        -Homepage $SPAReaderUri `
        -ReplyUrls $SPAReaderUri `
        -RequiredResourceAccess $readerAccesses
    $spaReaderApp

    $spaReaderSpn = New-AzureADServicePrincipal -AppId $spaReaderApp.AppId

    ###########################
    # Setup SPASalesWriter app:
    $writerAccesses = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]

    # API permission for "User.Read" in Microsoft Graph
    $writerUserRead = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
    $writerUserRead.Id = $userRead # "User.Read"
    $writerUserRead.Type = "Scope"

    $writerGraph = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $writerGraph.ResourceAppId = $microsoftGraphAPI # "Microsoft Graph API"
    $writerGraph.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]
    $writerGraph.ResourceAccess.Add($writerUserRead)

    # API permission for "Sales.Read" in SPA-FUNC
    $writerSalesRead = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
    $writerSalesRead.Id = $readPermission.Id # "Sales.Read"
    $writerSalesRead.Type = "Scope"

    # API permission for "Sales.Read" in SPA-FUNC
    $writerSalesReadWrite = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
    $writerSalesReadWrite.Id = $readWritePermission.Id # "Sales.ReadWrite"
    $writerSalesReadWrite.Type = "Scope"

    $writerApi = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $writerApi.ResourceAppId = $apiApp.AppId # "SPA FUNC"
    $writerApi.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]
    $writerApi.ResourceAccess.Add($writerSalesRead)
    $writerApi.ResourceAccess.Add($writerSalesReadWrite)

    # Add required accesses
    $writerAccesses.Add($writerGraph)
    $writerAccesses.Add($writerApi)

    $spaWriterApp = New-AzureADApplication -DisplayName $spaWriterAppName `
        -Oauth2AllowImplicitFlow $true `
        -Homepage $SPAWriterUri `
        -ReplyUrls $SPAWriterUri `
        -RequiredResourceAccess $writerAccesses
    $spaWriterApp

    $spaWriterSpn = New-AzureADServicePrincipal -AppId $spaWriterApp.AppId
}

$values = new-object psobject -property @{
    ReaderApp = $spaReaderApp.AppId;
    WriterApp = $spaWriterApp.AppId;
    ApiApp = $apiApp.AppId;
    TenantId = $tenant;
    ApplicationIdURI = $apiApp.IdentifierUris[0];
}
return $values
