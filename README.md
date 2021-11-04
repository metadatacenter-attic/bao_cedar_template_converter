BAO-TO-CEDAR Template Converter
=======================
A script to convert a BAO JSON schema template to a CEDAR schema template

# Installation

## Ruby Environment Setup (optional)

This is an __OPTIONAL__ step for those who don't have a functioning Ruby environment configured on their workstations.

### Install Homebrew

https://brew.sh/

```shell
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install rbenv using Homebrew

https://github.com/rbenv/rbenv

1. Install and update dependent libraries

```shell
$ brew install rbenv
$ brew upgrade rbenv ruby-build
```

2. Re-start your Terminal/Bash/Command Prompt application by fully quitting it and starting a new session.

### Install the latest Ruby version via rbenv

1. Execute these commands in your Terminal:

```shell
$ rbenv install -l
```

2. Choose the latest Ruby version from the list above (ex: 3.0.2) and execute these commands:

```shell
$ rbenv install 3.0.2
$ rbenv global 3.0.2
```

3. Check the installed Ruby version

```shell
$ rbenv versions
```

The output should show ALL Ruby versions installed and the one currently selected. The selected version should be one other than “system”, as in:

```shell
system
  2.5.8
  2.7.1
* 3.0.2 (set by /Users/mdorf/.rbenv/version)
```

4. <b>IMPORTANT:</b> Re-start your Terminal/Bash/Command Prompt application by fully quitting it and starting a new session.

5. Check the currently running Ruby version:

```shell
$ ruby --version
```
The output should match the Ruby version you've just installed. Example:

```shell
ruby 3.0.2p107 (2021-07-07 revision 0db68f0233) [x86_64-darwin18]
```

## Clone bao_cedar_template_converter repository

1. Navigate to (or create) the folder that will contain the BAO-CEDAR Converter (ex: ~/dev/scripts):

```shell
$ cd ~/dev/scripts
```

2. Clone the project from Github:

```shell
$ git clone https://github.com/metadatacenter/bao_cedar_template_converter.git
```

## Install project dependencies

1. Navigate to the BAO-CEDAR Converter folder (which was created by the `clone` command):

```shell
$ cd ~/dev/scripts/bao_cedar_template_converter
```

2. Run these commands:

```shell
$ git stash
$ git pull origin master
$ gem install bundler
$ bundle install  
```

## Configure the project

1. Create the file `bao_cedar_template_converter/config/config.yml` from the provided sample:

```shell
$ cp config/config.yml.sample config/config.yml
```

2. Open the file `bao_cedar_template_converter/config/config.yml` in your favorite text editor and replace the following attributes with your own:<br/></br>

    1. __bp_api_key__: "your-bioportal-api-key"
    2. __cedar_api_key__: "your-cedar-api-key"

* BioPortal API key can be found here: https://bioportal.bioontology.org/account
* CEDAR API key can be found here: https://cedar.metadatacenter.org/profile

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;For example (below API keys aren't real, they are provided for reference only):

```shell
bp_api_key: "17e2c93c-78f0-19e9-9d8b-029056aa3219"
cedar_api_key: "15ce8bb6cf5b5334c2a5646625w32149a944baa8ce5bb574555700c64ed776a9"
```

# Running the project

```shell
$ bundle exec ruby bao_cedar_template_converter.rb
```

## Parameters

The script accepts the following parameters (__all are OPTIONAL__):

```
    -s PATH_TO_SOURCE_TEMPLATE       Optional path to the source template file 
        --source                     Default: latest version of template is pulled from:
                                     https://github.com/cdd/bioassay-template/blob/master/data/template/schema.json
        
    -d PATH_TO_DESTINATION_TEMPLATE  Optional path to the destination template file
        --destination                Default: data/cedar-bao-schema.json
     
    -l, PATH_TO_LOG_FILE             Optional path to the log file        
        --log                        Default: logs/bao-to-cedar.log
         
    -p, [true/false]                 Optionally post template to CEDAR (if it passes validation)        
        --post-to-cedar              Default: false
         
    -h  --help                       Display help screen
```

Usage: __bao_cedar_template_converter.rb [options]__

## Run Examples

### Generate template

```shell
$ bundle exec ruby bao_cedar_template_converter.rb -s data/bao-schema.json -d data/cedar-bao-schema.json
```

### Generate template and post it to CEDAR

```shell
$ bundle exec ruby bao_cedar_template_converter.rb -s data/bao-schema.json -d data/cedar-bao-schema.json -p true`
```

### Generate template by pulling the source file from BAO Github repo and post it to CEDAR

```shell
$ bundle exec ruby bao_cedar_template_converter.rb -p true
```

## Sample Output

### Success

```shell
$ bundle exec ruby bao_cedar_template_converter.rb -p true
Generating CEDAR template...
Logging output to logs/bao-to-cedar.log
Source template: https://github.com/cdd/bioassay-template/blob/master/data/template/schema.json
Destination template: data/cedar-bao-schema.json
Downloading source template from Github...
Source template downloaded successfully. Processing...
Completed generating the new template.
Running the template through the CEDAR validator...
New template validated successfully.
Uploading new template to CEDAR...
New template 'common assay template' successfully uploaded to CEDAR.
Completed template conversion, validation and upload in 16.811006000003545 seconds.
```

### Failure

```shell
$ bundle exec ruby bao_cedar_template_converter.rb -s /Downloads/bao-schema-orig.json -p true
Generating CEDAR template...
Logging output to logs/bao-to-cedar.log
Source template: /Downloads/bao-schema-orig.json
Destination template: data/cedar-bao-schema.json
New template validated successfully by the CEDAR validator.
Uploading new template to CEDAR...
New template failed CEDAR upload with the following feedback (logged in logs/bao-to-cedar.log):

Response Code: 400
{
  "status": "BAD_REQUEST",
  "errorType": null,
  "errorKey": "templateNotCreated",
  "errorReasonKey": null,
  "message": "The template must not contain a non-null '@id' field!",
  "parameters": {
    "@id": "https://repo.metadatacenter.org/templates/88eafcd0-c2a1-4c9c-acec-387ce26cc21e"
  },
  "suggestedAction": "none",
  "originalException": null,
  "sourceException": null,
  "operation": null
}
Completed template conversion and validation in 19.352610000001732 seconds.
```