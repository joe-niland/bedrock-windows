<#
 # Create a fresh Wordpress bedrock VM using bedrock-ansible and vagrant. 
 #>
$DebugPreference = "SilentlyContinue" # Change to "Continue" in Dev

Set-Variable -Name $aptMirror -Value ""

function Download-File {
   param ( [string]$url, [string]$file )

   Write-Host "Downloading $url to $file"
   $downloader = new-object System.Net.WebClient
   $downloader.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;
   $downloader.DownloadFile($url, $file)
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

Write-Host Run this from your dev root directory, e.g. c:\users\me\documents\dev\
Write-Host Then pass in the project directory as a param.

# Args
# 0: installation directory

$projectDir = $Args[0]

if ($projectDir -eq "" -or $projectDir -eq $null) {
  Write-Error "Please specify the project installation directory as the first parameter. This is RELATIVE to the current working directory. E.g. project1 or project1\wp1\"
  exit
}

$installDir = Join-Path (Get-Location) $projectDir
Write-Host Installing to $installDir

if (Test-Path -Path $installDir) { 
  Write-Warning "$installDir already exists"
}


If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit
}


$choice = ""
while ($choice -notmatch "[y|n]") {
  $choice = read-host "Do you want to change the apt source to a mirror (https://launchpad.net/ubuntu/+archivemirrors) ? (y/N)"
}

if ($choice -eq "y") {
    $aptMirror = read-host "Enter the mirror server's host name, e.g. au.archive.ubuntu.com (blank will use the default)"
}

$choice = ""
while ($choice -notmatch "[y|n]"){
  $choice = read-host "Do you want to continue? (y/N)"
}

if ($choice -ne "y") {
  Write-Host "Quitting. Nothing was done..."
  exit
}

# Detect OS
$Win7 = [Environment]::OSVersion.Version -eq (new-object 'Version' 6,1)
$Win8 = [Environment]::OSVersion.Version -eq (new-object 'Version' 6,2)
$Win81 = [Environment]::OSVersion.Version -eq (new-object 'Version' 6,3)

## host machine
# Install chocolatey <-- https://chocolatey.org/
# todo: better way to detect chocolatey
if (!(Test-Path -Path "$Env:systemdrive\programdata\chocolatey\bin")) {
   Write-Host "Installing Chocolatey"

   iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

   #$pathEnv = [Environment]::GetEnvironmentVariable("Path", "User")
   #if (!$pathEnv.contains("")) {
   #$MachineModulePath = [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
   #[Environment]::SetEnvironmentVariable("PSModulePath", $UserModulePath + ";$MachineModulePath", "User")
#}

   Write-Host "Adding Chocolatey to global path"
   setx -m PATH "$env:Path;%systemdrive%\programdata\chocolatey\bin"

} else {
   Write-Host "Chocolatey is already installed"
}

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


# Download bedrock-ansible and bedrock
if (!(Test-Path "bedrock-ansible")) {
  Write-Host "Cloning bedrock-ansible"
  git clone https://github.com/roots/bedrock-ansible.git

  $bedrockAnsiblePath = Join-Path (Get-Location) "bedrock-ansible"

  $vagrantFilepath = ($bedrockAnsiblePath + "\Vagrantfile")

  # Back up Vagrantfile
  Move-Item $vagrantFilepath ($vagrantFilepath + ".original")

  # Get the Windows modifications
  Download-File https://gist.githubusercontent.com/starise/e90d981b5f9e1e39f632/raw/d96002240cf82c60538652d8fcbffea46f256303/Vagrantfile $vagrantFilepath
  Download-File https://gist.githubusercontent.com/starise/e90d981b5f9e1e39f632/raw/778325547427aec53bdc38aed217b311f0cb68f4/windows.sh ($bedrockAnsiblePath + "\windows.sh")

  # Set up Vagrantfile for our environment
  Write-Host "Editing bedrock-ansible\Vagrantfile and set: hostname and paths to web root"
  $hostName = "$projectDir.dev".Replace("_", "-"); # todo: clean host name properly
  Write-Host "Host name: $hostName"

  $vagrantSetAptMirror = ""
  if ($aptMirror -ne "") {
    Write-Host "Adding custom apt mirror"
    $vagrantSetAptMirror = "config.vm.provision ""shell"", inline: ""sudo sed -i.backup 's/archive.ubuntu.com/$aptMirror/g;s/security.ubuntu.com/$aptMirror/g' /etc/apt/sources.list"""
    (gc $vagrantFilepath -raw) | % { $_ -replace '(?s)(?<provider>config.vm.provider.+?end)', ('${provider}' + "`n`n$vagrantSetAptMirror") } | sc $vagrantFilepath
  }

  # Replace values
  (gc $vagrantFilepath) | ForEach-Object {
    Write-Debug $_
    if ($_.ToString() -like "*config.vm.hostname*") {
        $_.replace('example.dev', $hostName)
    } elseif ($_.ToString() -like "*config.vm.synced_folder*") {
        $_.replace('../example.dev', "../$projectDir").replace('/srv/www/example.dev', "/srv/www/$hostName") # We're using the hostName internally because the Ansible playbook expects it.
    } else {
        $_
    }
    Write-Debug $_
  } | sc $vagrantFilepath
  
  Write-Host "Editing bedrock-ansible\group_vars\development and set site-specific options"
  $groupVarsDevPath = ($bedrockAnsiblePath + "\group_vars\development")

  # Replace values
  (gc $groupVarsDevPath).replace("example.dev", $hostName) | sc $groupVarsDevPath
}

# Check if the 
if (!(Test-Path "$installDir")) {
  # Create location for bedrock project
  New-Item -Type Directory -Path $installDir | Out-Null

  Write-Host "Cloning bedrock into $installDir"
  git clone https://github.com/roots/bedrock.git $installDir
}


### Vagrant plugin setup
Update-VagrantPlugin "hostsupdater" $true
Update-VagrantPlugin "cachier" $false

Write-Host "You may like to make further updates to the Vagrantfile, or ansible yml files. Once complete, 'cd bedrock-ansible && vagrant up' or 'cd bedrock-ansible; vagrant up' from powershell"