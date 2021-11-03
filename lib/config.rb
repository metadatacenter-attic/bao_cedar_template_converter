require 'global'

Global.configure do |config|
  config.backend :filesystem, environment: :default, path: "config"
end


▲ dev/cedar/bao_cedar_template_converter ▶ bundle exec ruby bao_cedar_template_converter.rb -s ../bioassayexpress_schema_20211029/schema_2_PistoiaAllianceAssayTemplate.json -d cedar-pistoia-schema.json
Generating CEDAR template...
Logging output to logs/bao-to-cedar.log
Source template: ../bioassayexpress_schema_20211029/schema_2_PistoiaAllianceAssayTemplate.json
Destination template: cedar-pistoia-schema.json
Completed generating the new template.
Running the template through the CEDAR validator...
New template validated successfully.
Completed template conversion and validation in 66.22356600011699 seconds.