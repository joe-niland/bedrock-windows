Changelog
============

Version 0.3
------------

+ Bug fix: path could be truncated if current path + chocolatey path length greater than 1024 characters (thanks rtpHarry)
+ Bug fix: Default option when choosing to specify a custom apt mirror was not read correctly (thanks rtpHarry)
+ More reliable way to detect if Chocolatey already installed
+ Script clean up
+ Added check for git client in path

Version 0.2 (f0457c3)
------------

+ Starting work on allowing multiple sites on Bedrock VM.
+ Adding Vagrantfile template

Version 0.1 (bb0401c)
------------

+ Provision a new bedrock VM