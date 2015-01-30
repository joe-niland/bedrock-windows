<#
 # Create a fresh Wordpress bedrock VM using bedrock-ansible and vagrant.
 #
 # Version: 0.3
 #>
$DebugPreference = "Continue" # Change to "Continue" in Dev; "SilentlyContinue" in Production

Set-Variable -Name chocolateyPath -Value "$env:AllUsersProfile\chocolatey" -Option Constant
Set-Variable -Name chocolateyBinPath -Value "$chocolateyPath\bin" -Option Constant

Set-Variable -Name LOCAL_DNS_SUFFIX -Value "dev" -Option Constant

Set-Variable -Name vagrantConfigIncludeSitesFile -Value "   site_config = YAML::load_file(`"../.sites/sites.yml`")"
Set-Variable -Name vagrantConfigSyncedFolders -Value @"
  site_config['sites'].each do |site_name|
    config.vm.synced_folder '../' + site_name, '/srv/www/' + site_name + '/current',
        id: 'current',
        owner: 'vagrant',
        group: 'www-data',
        mount_options: ['dmode=776', 'fmode=775']
  end
"@

Set-Variable -Name ansibleWpSiteYaml -Value @"
  - site_name: example.dev
    site_hosts:
      - example.dev
      - 192.168.50.5
    user: vagrant
    group: www-data
    site_install: true
    site_title: Example Site
    admin_user: admin
    admin_password: admin
    admin_email: admin@example.dev
    system_cron: true
    multisite:
      enabled: false
    env:
      wp_home: http://example.dev
      wp_siteurl: http://example.dev/wp
      wp_env: development
      db_name: example_dev
      db_user: example_dbuser
      db_password: example_dbpassword
"@

function Download-File {
   param ( [string]$url, [string]$file )

   Write-Host "Downloading $url to $file"
   $downloader = new-object System.Net.WebClient
   $downloader.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;
   $downloader.DownloadFile($url, $file)
}

function Install-PsGet {

  $psget = get-module -listavailable | where-object { $_.name -eq "PsGet" }
  if ($psget -eq $null) {
      Write-Host "Installing PsGet"
      (new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | iex
      
  } else {
      Write-Host "PsGet already installed."
  }
  
}

function Install-Chocolatey {
    <#
        .DESCRIPTION
        Installs Chocolatey if current installation not detected.

    #>

  # Install chocolatey <-- https://chocolatey.org/
  if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
     Write-Host "Installing Chocolatey"

     Write-Host "The current value of your PATH variables prior to Chocolatey install: $env:Path"

     iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

     Write-Host "The current value of your PATH variables after Chocolatey install: $env:Path"

  } else {
     Write-Host "Chocolatey is already installed"
  }
  
}

function Install-HyperVSnapins {

  # Detect OS
  $Win7 = [Environment]::OSVersion.Version -eq (new-object 'Version' 6,1)
  $Win8 = [Environment]::OSVersion.Version -eq (new-object 'Version' 6,2)
  $Win81 = [Environment]::OSVersion.Version -eq (new-object 'Version' 6,3)

  # Add Hyper-V snapins
  if ($Win7) {
    $hyperV = clist -lo | where { $_ -match "^RemoteServerAdministrationTools\-Roles\-HyperV" }

    if ($hyperV) {
       Write-Host "Hyper-V Tools are already installed: $hyperV"
    } else {
       Write-Host "Installing Hyper-V Tools"
       cinst -source windowsfeatures RemoteServerAdministrationTools RemoteServerAdministrationTools-Roles  RemoteServerAdministrationTools-Roles-HyperV
    }
  }

  if ($Win8) {
    $hyperV = clist -lo | where { $_ -match "^Microsoft\-Hyper\-V\-Management\-PowerShell" }

    if ($hyperV) {
       Write-Host "Hyper-V Tools are already installed: $hyperV"
    } else {
       Write-Host "Installing Hyper-V Tools"
       cinst -source windowsfeatures Microsoft-Hyper-V-Management-PowerShell
    }
  }

}

function Install-VirtualBox {

  # Install VirtualBox using Chocolatey
  $vBox = clist -lo | where { $_ -match "^virtualbox\s[0-9]+" }

  if ($vBox) {
     Write-Host "VirtualBox is already installed: $vBox"
  } else {
     Write-Host "Installing VirtualBox"
     cinst virtualbox 
  }

  # Install Vagrant using Chocolatey
  $vagrantPackages = clist -lo | where { $_ -match "^vagrant\s[0-9]+" }

  if ($vagrantPackages) {
     Write-Host "Vagrant is already installed: $vagrantPackages"
  } else {
     Write-Host "Installing vagrant"
     cinst vagrant
  }

}

function Update-VagrantPlugin {
    <#
        .DESCRIPTION
        Update a vagrant plugin.

        .PARAMETER pluginName
        Specifies the plugin name. Specify this without using the vagrant- prefix that some plugins use.

        .PARAMETER updatePlugins
        If true, will run vagrant plugin update.

        .EXAMPLE
        Update-VagrantPlugin -pluginName hostsupdater

        .NOTES
        
        #>
    param ( [string]$pluginName, [bool]$updatePlugins )

    $pluginFound = vagrant plugin list | where { $_ -match "^vagrant\-$pluginName" }

    if ($pluginFound) {
       Write-Host "vagrant-$pluginName plugin is already installed: $pluginFound"
       if ($updatePlugins) {
          Write-Host "checking for vagrant plugin updates"
          vagrant plugin update
       }
    } else {
       Write-Host "Installing vagrant-$pluginName plugin"
       vagrant plugin install vagrant-$pluginName
    }
}

function Install-BedrockAnsible {
  <#
        .DESCRIPTION
        Downloads and configures the bedrock-ansible project.
        
        .PARAMETER bedrockAnsiblePath
        Installation location for bedrock-ansible project

  #>

  # Download bedrock-ansible and bedrock
  if (Test-Path "bedrock-ansible") {
    
    Write-Host "bedrock-ansible directory already exists"

  } else {

    $aptMirror = ""

    # Set hostname
    $choice = read-host "Please specify the Virtual Machine's host name (blank to use default: $hostName)"

    if ($choice -ne "") {
        $hostName = $choice
    }

    # Set apt mirror (optional)
    $choice = read-host "Do you want to change the apt source to a mirror (https://launchpad.net/ubuntu/+archivemirrors) ? (y/N)"

    if ($choice -eq "y") {
        $aptMirror = read-host "Enter the mirror server's host name, e.g. au.archive.ubuntu.com (blank to use Ubuntu's default)"
    }

    $hostName = $hostName.Replace("_", "-"); # todo: clean host name properly

    Write-Host "Cloning bedrock-ansible"
    git clone https://github.com/roots/bedrock-ansible.git

    $vagrantFilepath = ($bedrockAnsiblePath + "\Vagrantfile")

    # Back up Vagrantfile
    Move-Item $vagrantFilepath ($vagrantFilepath + ".original")

    # Get the Windows modifications
    # Download-File https://gist.githubusercontent.com/starise/e90d981b5f9e1e39f632/raw/d96002240cf82c60538652d8fcbffea46f256303/Vagrantfile $vagrantFilepath
    Download-File https://raw.githubusercontent.com/joe-niland/bedrock-windows/master/templates/Vagrantfile.template $vagrantFilepath
    Download-File https://gist.githubusercontent.com/starise/e90d981b5f9e1e39f632/raw/778325547427aec53bdc38aed217b311f0cb68f4/windows.sh ($bedrockAnsiblePath + "\windows.sh")

    $vagrantSetAptMirror = ""
    if ($aptMirror -ne "") {
      Write-Host "Adding custom apt mirror: $aptMirror"
      $vagrantSetAptMirror = "config.vm.provision ""shell"", inline: ""sudo sed -i.backup 's/archive.ubuntu.com/$aptMirror/g;s/security.ubuntu.com/$aptMirror/g' /etc/apt/sources.list"""
      (gc $vagrantFilepath -raw) | % { $_ -replace '(?s)(?<provider>config.vm.provider.+?end)', ('${provider}' + "`n`n$vagrantSetAptMirror") } | sc $vagrantFilepath
    }

    # Set up Vagrantfile for our environment
    Write-Host "Editing bedrock-ansible\Vagrantfile and set: hostname and paths to web root"
    Write-Host "Using host name: $hostName"

    # Modify vagrantfile to handle multiple sites
    # (gc $vagrantFilepath -raw) | % { $_ -replace '(?s)(?<syncfolder>config.vm.synced_folder.+?\])', ("$vagrantConfigIncludeSitesFile`n$vagrantConfigSyncedFolders") } | sc $vagrantFilepath

    # Modify selected lines in the Vagrantfile
    (gc $vagrantFilepath) | ForEach-Object {
      Write-Debug $_
      if ($_.ToString() -like "*config.vm.hostname*") {
          $_.replace('example.dev', $hostName)
      } elseif ($_.ToString() -like "*config.vm.synced_folder*") {
          # $_.replace('../example.dev', "../$projectDir").replace('/srv/www/example.dev', "/srv/www/$hostName") # We're using the hostName internally because the Ansible playbook expects it.
          "$vagrantConfigIncludeSitesFile`n$vagrantConfigSyncedFolders"
      } else {
          $_
      }
      # Write-Debug $_
    } | sc $vagrantFilepath
    
  }

}

function Create-SitesFile {
   <#
        .DESCRIPTION
        Adds entry for our project to the sites index file. Creates sites yaml file and .sites\ directory if they do not already exist.
        
        .PARAMETER installDir
        Site local directory path.

  #>
  param ( [string]$installDir )

  $sitesDir = ".\.sites\"
  $sitesFile = ".\.sites\sites.yml"

  $siteName = (gi $installDir).Name

  if (!(Test-Path $sitesDir)) {
    New-Item -Type Directory -Name $sitesDir | Out-Null
  }

  if (!(Test-Path $sitesFile)) {
    Write-Host "Creating sites file: $sitesFile"
    New-Item -Type File -Name $sitesFile | Out-Null
    Add-Content $sitesFile "sites:"
  }

  $sitesFile = (Resolve-Path $sitesFile)

  # import-module PsGet
  import-module PowerYaml
  $sites = Get-Yaml -FromFile "$sitesFile"

  if (!($sites.Values.Contains($siteName))) {
    Write-Host "Adding site to sites file: $sitesFile"
    Add-Content $sitesFile "`n  - ${siteName}"
  } else {
    Write-Host "$siteName already added to sites file"
  }

  # Remove any blank lines
  (gc $sitesFile) | ? {$_.trim() -ne "" } | sc $sitesFile
}

function Create-GroupVarsEntry {
   <#
        .DESCRIPTION
        Adds WordPress site to Ansible group_vars/development yaml file.
        
        .PARAMETER hostName
        Site local DNS name.

        .PARAMETER ansibleRoot
        Path to the Bedrock Ansible project directory.

  #>
  param ( [string]$hostName, [string]$ansibleRoot )

  $groupVarsDevPath = ($ansibleRoot + "\group_vars\development")
  Write-Debug "Group vars dev path: $groupVarsDevPath"

  # Generate site-specific values
  $site_dns = "$hostName"
  $site_name = $site_dns.replace('.', '_')
  Write-Debug "Site DNS: $site_dns; Site Name: $site_name"

  # import-module PsGet
  import-module PowerYaml
  $group_vars = Get-Yaml -FromFile "$groupVarsDevPath"

  $site = $group_vars.wordpress_sites | Where-Object { $_.site_name -eq $site_dns }

  if ($site -eq $null) {

    Write-Host "Adding WordPress site config for $hostname to bedrock-ansible\group_vars\development"

    $newSiteYamlString = $ansibleWpSiteYaml

    $rand = New-Object System.Random
    # Generate a new 8 character password for MySQL
    1..8 | ForEach { $dbPassword = $dbPassword + [char]$rand.next(33, 127) }

    # Replace values
    $newSiteYamlString = $newSiteYamlString.replace("example.dev", $site_dns)
    # (gc $groupVarsDevPath).replace("example.dev", $site_dns) | sc $groupVarsDevPath
    $newSiteYamlString = $newSiteYamlString.replace("example_dev", $site_name)
    # (gc $groupVarsDevPath).replace("example_dev", $site_name) | sc $groupVarsDevPath
    $newSiteYamlString = $newSiteYamlString.replace("Example Site", $hostname)
    # (gc $groupVarsDevPath).replace("Example Site", $hostname) | sc $groupVarsDevPath
    $newSiteYamlString = $newSiteYamlString.replace("example_dbuser", "u_$hostname")
    # (gc $groupVarsDevPath).replace("example_dbuser", "u_$hostname") | sc $groupVarsDevPath # todo: check length here
    $newSiteYamlString = $newSiteYamlString.replace("example_dbpassword", "$dbPassword")
    # (gc $groupVarsDevPath).replace("example_dbpassword", $dbPassword) | sc $groupVarsDevPath

    $newSiteYaml = New-Object System.Collections.Hashtable
    $newSiteYaml += Get-Yaml -FromString $newSiteYamlString

    $group_vars.wordpress_sites += $newSiteYaml

    $group_vars | Export-Yaml $groupVarsDevPath $false
  } else {
    Write-Host "Ansible site config already exists for $site_dns"
  }
}




#################################################################################################################################################
## START SCRIPT

Write-Host Run this from your dev root directory, e.g. c:\users\me\documents\dev\, passing in the project directory as a param.

# Args
# 0: installation directory

$projectDir = $Args[0]

if ($projectDir -eq "" -or $projectDir -eq $null) {
  Write-Error "Please specify the project installation directory as the first parameter. This is RELATIVE to the current working directory. E.g. project1 or project1\wp1\"
  exit
}

if (!(Get-Command "git" -ErrorAction SilentlyContinue))
{ 
   Write-Error "Please ensure you have a git client in your path. Try https://windows.github.com/"
   exit
}

# Set VM hostname
$hostName = "$projectDir.$LOCAL_DNS_SUFFIX"

$installDir = Join-Path (Get-Location) $projectDir
Write-Host Installing to $installDir

if (Test-Path -Path $installDir) { 
  Write-Warning "$installDir already exists. Exiting"
  exit
}


If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit
}

# Continue?
$choice = read-host "Do you want to continue? (y/N)"

if ($choice -ne "y") {
  Write-Host "Quitting. Nothing was done..."
  exit
}



# Install prerequisites

$bedrockAnsiblePath = Join-Path (Get-Location) "bedrock-ansible"

Install-Chocolatey
Install-PsGet
# Install-HyperVSnapins
Install-VirtualBox
Install-BedrockAnsible $bedrockAnsiblePath

# Check if the project directory already exists
if (!(Test-Path "$installDir")) {
  # Create location for bedrock project
  New-Item -Type Directory -Path $installDir | Out-Null

  Write-Host "Cloning bedrock into $installDir"
  git clone https://github.com/roots/bedrock.git $installDir

  Create-SitesFile $installDir
  Create-GroupVarsEntry $hostname $bedrockAnsiblePath
}

### Vagrant plugin setup
Update-VagrantPlugin "hostsupdater" $true
Update-VagrantPlugin "cachier" $false

Write-Host "`n`n+++ Done +++"
Write-Host "`n`nWordpress configuration details can be found in bedrock-ansible\group_vars\development`n"
Write-Host "You may want to edit this file to specify Site Title, Email, db connection properties, etc"
Write-Host "You may also like to make further updates to the Vagrantfile, or ansible yml files.`n`nOnce complete, 'cd bedrock-ansible && vagrant up' or 'cd bedrock-ansible; vagrant up' from powershell"