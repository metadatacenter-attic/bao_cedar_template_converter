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
         
    -h  --help                       Display help screen
</pre>

Usage: __bao_cedar_template_converter.rb [options]__

Run Example:
---------------
`$ bundle exec ruby bao_cedar_template_converter.rb -s data/bao-schema.json -d data/cedar-bao-schema.json`

