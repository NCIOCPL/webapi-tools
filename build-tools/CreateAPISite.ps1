param([string]$site_name = "", [string]$app_name = "", [string]$app_version = "", [string]$site_hostname = "");

function Main() {
	## The WebAdministration module requires elevated privileges.
	$isAdmin = Is-Admin;
	if( $isAdmin ) {
		Write-Host -foregroundcolor 'green' "Starting...";
		Import-Module WebAdministration;
		CreateSite;
	} else {
		Write-Host -foregroundcolor 'red' "This script must be run from an account with elevated privileges.";
	}
}

function Is-Admin {
 $id = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent());
 $id.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator);
}

function CreateSite() {
	if ($site_name -eq "")
	{
		Write-Host -foregroundcolor 'red' "ERROR: Site Name must not be null.";
		exit;
	}

	if ($site_hostname -eq "")
	{
		Write-Host -foregroundcolor 'red' "ERROR: Site Host Name must not be null.";
		exit;
	}

	$fileLoc = "D:\WCMS_Code_Folder\";

	$versionCodeFolder = $fileLoc + $site_name + "\" + $app_version;

	$contentRoot = "D:\Content";
	$sitesRoot = "D:\Content\APISites";
	$sitePath = $sitesRoot + "\" + $site_name;
	$sitePhysicalPath = $sitePath + "\root";
	$appPath = $sitePath + "\" + $app_name;
	$versionAppPath = $sitePath + "\" + $app_version;

	## Make site directories
	## Should check non-existence first
	foreach ( $folder in (
			$contentRoot,
			$sitesRoot,
			$sitePath,
			$sitePhysicalPath,
			$appPath
			)
		)
	{
		if (Test-Path $folder)
		{
			Write-Host "WARNING: The path ${folder} already exists. Skipping creation.";
		}
		else
		{
			Write-Host "INFO: Creating folder ${folder}.";
			New-Item -ItemType directory -Path $folder;     
		}
	}
	
	## Make version directory and copy files
	if (Test-Path $versionAppPath)
	{
		Write-Host "WARNING: The ${app_version} folder path ${versionAppPath} already exists. Skipping creation.";

		Write-Host "INFO: Copying files from ${versionCodeFolder} to ${versionAppPath}.";
		Get-ChildItem $versionCodeFolder | Copy-Item -Destination $versionAppPath -force;
	}
	else
	{
		Write-Host "INFO: Creating folder ${versionAppPath}.";
		New-Item -ItemType directory -Path $versionAppPath;
		
		if (!(Test-Path($versionCodeFolder)))
		{
			Write-Host -foregroundcolor 'red' "ERROR: ${app_version} code folder ${versionCodeFolder} does not exist.";
			Exit;
		}
		else
		{
			Write-Host "INFO: Copying files from ${versionCodeFolder} to ${versionAppPath}.";
			Get-ChildItem $versionCodeFolder | Copy-Item -Destination $versionAppPath;
		}
	}

	###### Setup Web Site ######

	## Set up app pool/website variables
	$siteAppPool = $site_name;
	$siteIISAppPool = "IIS:\AppPools\" + $siteAppPool;
	$siteIISPath = "IIS:\Sites\" + $site_name;
	$appAppPool = $site_name + "-" + $app_version;
	$appIISAppPool = "IIS:\AppPools\" + $appAppPool;
	$appIISPath = $siteIISPath + "\" + $app_name + "\" + $app_version;
	$appVD = $app_name + "/" + $app_version;

	## Create application pool for website
	if((Test-Path $siteIISAppPool) -eq 0)
	{
		New-WebAppPool -Name $siteAppPool;
		Set-ItemProperty -Path $siteIISAppPool -Name managedRuntimeVersion -Value "";
	}
	else
	{
		Write-Host "WARNING: Application pool ${siteAppPool} already exists. Skipping creation.";
	}

	## Create application pool for version application
	if((Test-Path $appIISAppPool) -eq 0)
	{
		New-WebAppPool -Name $appAppPool;
		Set-ItemProperty -Path $appIISAppPool -Name managedRuntimeVersion -Value "";
	}
	else
	{
		Write-Host "WARNING: Application pool ${appAppPool} already exists. Skipping creation.";
	}

	## Create site and application
	if((Get-Item $siteIISPath -ErrorAction SilentlyContinue) -eq $null)
	{
		## If website doesn't already exist, create it
		New-Website -Name $site_name -Port 443 -HostHeader $site_hostname -PhysicalPath $sitePhysicalPath -ApplicationPool $siteAppPool -Ssl;
		New-WebBinding -Name $site_name -Protocol "http" -Port 80 -HostHeader $site_hostname;
	}
	else
	{
		Write-Host "WARNING: Website ${site_name} already exists. Skipping creation.";
	}
	
	## If web application for version doesn't already exist, create it
	if((Get-WebVirtualDirectory -Site $site_name -Name $app_name) -eq $null)
	{
		New-WebVirtualDirectory -Site $site_name -Name $app_name -PhysicalPath $appPath;
	}
	else
	{
		Write-Host "WARNING: Virtual directory ${app_name} already exists. Skipping creation.";
	}
	
	if((Get-WebApplication -Site $site_name -Name $appVD) -eq $null)
	{
		New-WebApplication -Name $appVD -Site $site_name -PhysicalPath $versionAppPath -ApplicationPool $appAppPool;
	}
	else
	{
		Write-Host "WARNING: Application ${appVD} already exists. Skipping creation.";
	}
}

Main;
Read-Host -Prompt "Press Enter to exit."
