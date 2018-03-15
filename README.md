BAO-TO-CEDAR Template Converter
=======================
A script to convert a BAO JSON schema template to a CEDAR schema template

Installation
----------------
1. Clone this repo and run `bundle install`
2. Copy __config/config.yml.sample__ to __config/config.yml__
3. Edit __config/config.yml__ and replace the following attributes with your own:
    1. __bp_api_key__: "your-bioportal-api-key"
    2. __cedar_api_key__: "your-cedar-api-key"

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;BioPortal API key can be found here: https://bioportal.bioontology.org/account<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;CEDAR API key can be found here: https://cedar.metadatacenter.org/profile

Execution:
----------------
The script accepts the following parameters (all are OPTIONAL):
<pre>
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
</pre>

Usage: __bao_cedar_template_converter.rb [options]__

Run Example:
---------------
#### Generate template:

`$ bundle exec ruby bao_cedar_template_converter.rb -s data/bao-schema.json -d data/cedar-bao-schema.json`

#### Generate template and post it to CEDAR:

`$ bundle exec ruby bao_cedar_template_converter.rb -s data/bao-schema.json -d data/cedar-bao-schema.json -p true`

#### Generate template by pulling the source file from BAO Github repo and post result to CEDAR:

`$ bundle exec ruby bao_cedar_template_converter.rb -p true`

Sample Output:
----------------
#### Success:
<pre>
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
New template successfully uploaded to CEDAR.
Completed template conversion, validation and upload in 16.811006000003545 seconds.
</pre>
#### Failure:
<pre>
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
</pre>