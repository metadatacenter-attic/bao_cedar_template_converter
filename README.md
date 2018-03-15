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

Execution:
----------------
The script accepts the following parameters (all are OPTIONAL):
<pre>
    -s PATH_TO_SOURCE_TEMPLATE       Optional path to the source template file 
        --source                     Default: data/bao-schema.json
        
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

Sample Output:
----------------
#### Success:
<pre>
$ bundle exec ruby bao_cedar_template_converter.rb -s /Downloads/bao-schema-orig.json -p true
Generating CEDAR template...
Logging output to logs/bao-to-cedar.log
Source template: /Downloads/bao-schema-orig.json
Destination template: data/cedar-bao-schema.json
New template validated successfully by the CEDAR validator.
Uploading new template to CEDAR...
New template successfully uploaded to CEDAR.
Completed template conversion, validation and upload in 16.74563400000261 seconds.
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