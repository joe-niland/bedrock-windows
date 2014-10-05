# Create a fresh Wordpress bedrock VM using bedrock-ansible and vagrant. 
echo Run this from your dev root directory, e.g. c:\users\me\documents\dev\
echo Then pass in the project directory as a param.

# Args
# 0: installation directory

installDir = $1

# todo: add validation

# Download bedrock-ansible and bedrock
if [! -d "bedrock-ansible" ]; then
   echo "Cloning bedrock-ansible"
	git clone https://github.com/roots/bedrock-ansible.git
	echo "edit bedrock-ansible\Vagrantfile and set path to wordpress location"
	echo "edit bedrock-ansible\group_vars\all and set site-specific options"
fi

if (! -d installDir ]; then
   echo "Cloning bedrock into $installDir"
	git clone https://github.com/roots/bedrock.git $installDir 
fi

brew install virtualbox
brew install vagrant
brew install ansible

vagrant plugin update
vagrant plugin install vagrant-hostsupdater

echo "Once the above files are updated, cd bedrock-ansible && vagrant up"
