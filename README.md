bedrock-windows
===============

A PowerShell script to automate creation of a new [bedrock](https://github.com/roots/bedrock)-based Wordpress site on Windows, using [bedrock-ansible](https://github.com/roots/bedrock-ansible) and [Vagrant](http://www.vagrantup.com/). It's aimed at someone who has none of the pre-requisites already installed, but can be used by anyone on Windows.

about
=====

This PowerShell script makes use of [Chocolatey](http://chocolatey.org) to provision your Windows machine with everything you need to create a new bedrock instance. It's been tested on Windows 7 and 8.1.
It is designed to be idempotent so you can run it as many times as you want.

**The script needs some clean-up but it works!**

requirements
------------

  + a working git executable in your PATH

  If you don't have this, I recommend downloading [GitHub for Windows](https://windows.github.com/), and opening the "Git Shell" shortcut that it installs.

  I didn't include a git command line installation in this script because I didn't want to the script to be opinionated about which git client to use.

dependencies
--------------
The script installs [Chocolatey](http://chocolatey.org) and uses it to install the Windows versions of the required prerequisites:
* vagrant
* virtualbox

It also uses the PowerShell module manager to import a required module (PowerYAML):
* [PsGet](http://psget.net/)
    
It then pulls git projects from:
* [bedrock](https://github.com/roots/bedrock), and 
* [bedrock-ansible](https://github.com/roots/bedrock-ansible). 

.. and splices in a [gist](https://gist.github.com/starise/e90d981b5f9e1e39f632) from [Andrea Brandi](https://github.com/starise).

why did I create this?
--------------------
Whenever I have to set up a new open-source framework/tool (particularly on Windows), it invariably involves piecing together instructions from readme's/gists on github and/or peoples' blogs. I feel that this type of thing should live in a script! 

This is so:
* it can be reused - only a few people need to go through the pain
* it can be versioned; and improvements tracked
* in some cases, it can be rolled into the target project
* if the script is well organised, it can serve in place of documentation, which noone tends to want to write.

BTW, if you're more of a yeoman type of Sir, head over to: https://github.com/paramburu/generator-bedrock

usage
=====

notes
-------

The instructions below assume the following:
+ you organise your wordpress themes under a common directory, say `c:\dev\wp-themes`
+ you'll maintain a single `bedrock-ansible` directory under this common directory. Within this `bedrock-ansible` directory you'll maintain one **or more** local developments sites. This essentially maps to one Vagrant-managed VM. 

    Remember that Ansible's top level playbook (`site.yml`) file defines your whole infrastructure, so you can define multiple sites and/or hosts.

steps to generate your VM and project base
------------------------------------------

1. git clone https://github.com/joe-niland/bedrock-windows.git
2. Copy provision-bedrock.ps1 to your wordpress development root, e.g. c:\dev\wp themes\

    or, even better: 

    ```
    cd "c:\dev\wp themes\" && mklink provision-bedrock.ps1 path\to\cloned\repo\provision-bedrock.ps1
    ```

    or in powershell:

    ```
    cd "c:\dev\wp themes\"; cmd /c mklink provision-bedrock.ps1 path\to\cloned\repo\provision-bedrock.ps1
    ```

3. Open a PowerShell console and type: `.\provision-bedrock.ps1 project_name`, where project_name is the name of your theme.
4. The script will ask if you want to set a custom apt mirror. This can make it faster to update packages in the VM. Enter `n` if you want to use the default 'archive.ubuntu.com'.
5. The script will ask you to continue, type `y` if you would like to continue.
6. Once the script has completed, you may want to edit the following files to your preference:
   1. _your_dev_root\project_name\bedrock-ansible\Vagrantfile_
   2. _your_dev_root\project_name\bedrock-ansible\group_vars\development_

   See https://github.com/roots/bedrock-ansible#usage for details.
7. Then, navigate to _your_dev_root\project_name\bedrock-ansible_ and type `vagrant up`
8. Open your browser and go to 'project_name.dev/' to view your freshly created Bedrock site!

generating your Nth project
-----------------------------

As mentioned above there's no need to maintain multiple bedrock-ansible instances (and therefore multiple VMs) unless you really need to seperate them.

You can create as many subsequent projects as you like using this script. It will not touch the `bedrock-ansible` directory if it already exists.

contributions
=============
Sure! Right now I'd love people to test this on Windows to make sure we've ironed out all the edge cases. Please open an issue with any comments/questions/problems.

todo
====
1. Implement as PowerShell module
1. Reload path env var
2. Handle non-standard Chocolatey install.