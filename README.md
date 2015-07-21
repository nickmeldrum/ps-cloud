# ps-cloud - A set of PowerShell Modules for automating "the cloud"

## Introduction

## How to setup

 1. Ensure you have satisfied the prerequisites below.
 2. In a powershell console run the command ".\load-module.ps1" and this will load in all the cloud modules and output a list of commands you can execute.
 3. The azure commands will always log you in if you aren't already logged in, but if the azure ps module or the azure xpat cli isn't loaded, please run Setup-AzureApi before running the commands.
 4. Run "man commandname" to see more details about running each command.

## Assumptions/ Prerequisites

### Github / Bitbucket commands

If you want to run the github commands (including the bitbucket ones) we assume that git is installed and in the path. You will also need the following global variables set (you can either add them to your powershell profile or just set them before calling the commands):

  * $githubUsername
  * $githubToken (an auth token you have to create here: https://github.com/settings/tokens)

If you are using the bitbucket version of the repo commands you will need:

  * $bitbucketUsername
  * $bitbucketToken

### Azure commands

We assume you have installed azure for powershell using the Microsoft Web Platform Installer and have node.js and npm installed correctly and in the path.

We also assume you have installed the azure ps module and the azure xpat cli, but if you haven't you can just run the function Setup-AzureApi first.

We also assume you are using a "microsoft" account (an account you have at https://login.live.com/) instead of using AD or an "organizational" account and that you have downloaded your .publishsettings file and put it in the executing directory.

If you are using the github deployment hooks, you will also need the following variable setup as above (because it seems azure isn't using auth tokens like a good boy):
  * $githubPassword

Some Azure commands make use of grep and gawk - so make sure you have these unix tools in your path. (Easiest way on windows is to do the "full path" option when installing msysgit as they are shipped in the Git/bin directory.

### CAREFUL!

Your .publishsettings file has an access certificate in it. Keep this and your github password and auth tokens secure. Don't commit them to version control!

## Usage

TODO:!

## Known issues

TODO:!

