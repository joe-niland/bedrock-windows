<#
 # Create a fresh Wordpress bedrock VM using bedrock-ansible and vagrant. 
 #>
$DebugPreference = "SilentlyContinue" # Change to "Continue" in Dev

Write-Host Run this from your dev root directory, e.g. c:\users\me\documents\dev\
Write-Host Then pass in the project directory as a param.

# Args
# 0: path to command, e.g. d:\scripts\copymess.vbs
# 1: Description of task

$installDir = $Args[0]


if ($installDir -eq "" -or $installDir -eq $null) {
  Write-Error "Please specify the installation directory as the first parameter. This is RELATIVE to the current working directory. E.g. project1 or project1\wp1\"
  exit
}

$installDir = Join-Path (Get-Location) $installDir
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
while ($choice -notmatch "[y|n]"){
  $choice = read-host "Do you want to continue? (y/N)"
}

if ($choice -ne "y") {
  Write-Host "Quitting. Nothing was done..."
  exit
}

# Create location for bedrock project
if (!(Test-Path -Path $installDir)) {
   New-Item -Type Directory -Path $installDir | Out-Null
}

## host machine
# Install chocolatey <-- http://chocolatey.org/
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

# Add Hyper-V snapins to WindowsIdentity
$hyperV = clist -lo | where { $_ -match "^RemoteServerAdministrationTools\-Roles\-HyperV" }

if ($hyperV) {
   Write-Host "Hyper-V Tools are already installed: $hyperV"
} else {
   Write-Host "Installing Hyper-V Tools"
   cinst -source windowsfeatures RemoteServerAdministrationTools RemoteServerAdministrationTools-Roles  RemoteServerAdministrationTools-Roles-HyperV
}


# Download bedrock-ansible and bedrock
if (!(Test-Path "bedrock-ansible")) {
   Write-Host "Cloning bedrock-ansible"
	git clone https://github.com/roots/bedrock-ansible.git
	Write-Host "edit bedrock-ansible\Vagrantfile and set path to wordpress location"
	Write-Host "edit bedrock-ansible\group_vars\all and set site-specific options"
}

if (!(Test-Path "$installDir")) {
   Write-Host "Cloning bedrock into $installDir"
	git clone https://github.com/roots/bedrock.git $installDir 
}

### Vagrant setup
$vagrantUpdateRun = $false
$vagrantSalt = vagrant plugin list | where { $_ -match "^vagrant\-salt" }

if ($vagrantSalt) {
   Write-Host "vagrant-salt plugin is already installed: $vagrantSalt - checking for updates"
   vagrant plugin update
   $vagrantUpdateRun = $true
} else {
   Write-Host "Installing vagrant-salt plugin"
   vagrant plugin install vagrant-salt
}

$vagrantHostsUpdater = vagrant plugin list | where { $_ -match "^vagrant\-hostsupdater" }

if ($vagrantHostsUpdater) {
   Write-Host "vagrant-hostsupdater plugin is already installed: $vagrantHostsUpdater"
   if (!$vagrantUpdateRun) {
      Write-Host "checking for vagrant plugin updates"
      vagrant plugin update
   }
} else {
   Write-Host "Installing vagrant-hostsupdater plugin"
   vagrant plugin install vagrant-hostsupdater
}

Write-Host "Once the above files are updated, cd bedrock-ansible && vagrant up"
