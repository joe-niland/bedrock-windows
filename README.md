bedrock-windows
===============
A script to automate creation of a new [bedrock](https://github.com/roots/bedrock)-based Wordpress site, using [bedrock-ansible](https://github.com/roots/bedrock-ansible) and [Vagrant](http://www.vagrantup.com/). It's aimed at someone who has none of the pre-requisites already installed.

about
=====
This PowerShell script makes use of http://chocolatey.org to provision your Windows machine with everything you need to create a new bedrock instance. It's been tested on Windows 7 and 8.1.
It is designed to be idempotent so you can run it as many times as you want.

Why did I create it?
--------------------
Whenever I have to set up a new open-source framework/tool (particularly on Windows), it invariably involves piecing together instructions from readme's on github and/or peoples' blogs. I feel that this type of thing should live in a script! This is so:
* it can be reused - only a few people need to go through the pain
* it can be versioned
* in some cases, it can be rolled into the target project

BTW, if you're more of a yeoman type of sir, head over to: https://github.com/paramburu/generator-bedrock

usage
=====
1. git clone https://github.com/joe-niland/bedrock-windows.git
2. Copy provision-bedrock.ps1 to your wordpress development root, e.g. c:\dev\wp themes\
3. Open a command prompt as Admin and type: `provision-bedrock.ps1 project_name`, where project_name is the name of your theme.
4. The script will ask you to continue, type `y` if you would like to continue.
5. Once the script has completed, you will need to edit the following files to match your environment:
   1. _your_dev_root\project_name\bedrock-ansible\Vagrantfile_
   2. _your_dev_root\project_name\bedrock-ansible\group_vars\development_

   See https://github.com/roots/bedrock-ansible#usage for details.
6. Then, navigate to _our_dev_root\project_name\bedrock-ansible_ and type `vagrant up`

contributions
=============
Sure! Right now I'd love people to test this on Windows to make sure we've ironed out all the edge cases. Please open an issue with any comments/questions/problems.

todo
====
1. Reload path env var
2. Automate editing of ansible and Vagrant files
3. Handle non-standard Chocolatey install.
4. Implement as a [BoxStarter](http://boxstarter.org/) package.
