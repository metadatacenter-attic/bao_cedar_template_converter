require 'date'
require 'multi_json'
require 'pry'
require 'securerandom'
require 'rest-client'
require 'optparse'
require 'benchmark'
require 'octokit'
require_relative 'lib/config'

RESPONSE_UPLOAD_SUCCESS = 201
RESPONSE_OK = 200
BAO_GITHUB_PATH = "https://github.com/#{Global.config.bao_github_repo_user}/#{Global.config.bao_template_github_repo}/blob/master#{Global.config.bao_github_template_path}"

def sanitize_input_for_json(str)
  str.gsub("\"", "'").gsub(/[\r\n\t]/, " ")
end

def create_base_entity(item, type)
  base_template = File.read(Global.config.cedar_template % {name: type})
  template_fields = {
      guid: SecureRandom.uuid,
      name: sanitize_input_for_json(item["name"]),
      descr: sanitize_input_for_json(item["descr"]),
      created_on: DateTime.now.strftime
  }
  base_template % template_fields
end

def get_acronym_from_id(id)
  id.to_s.split("/")[-1]
end

def get_bao_template_from_github()
  user = Octokit.user(Global.config.bao_github_repo_user)
  repos = Hash[user.rels[:repos].get.data.map {|r| [r.name, Octokit::Repository.new(r.full_name)]}]
  bioassay_repo = repos[Global.config.bao_template_github_repo]
  api_response = Octokit.contents bioassay_repo, path: Global.config.bao_github_template_path
  Base64.decode64(api_response.content)
end

def get_bp_ontologies()
  response_raw = RestClient.get(Global.config.bp_base_rest_url + Global.config.bp_ontologies_endpoint, {Authorization: "apikey token=#{Global.config.bp_api_key}", params: {no_links: true, no_context: true}})
  bp_ontologies = {}

  if response_raw.code === RESPONSE_OK
    response = MultiJson.load(response_raw)
    response.each {|ont| bp_ontologies[ont["acronym"]] = ont["name"]}
  else
    raise Exception, "Unable to query BioPortal #{Global.config.bp_ontologies_endpoint} endpoint. Response code: #{response_raw.code}."
  end

  bp_ontologies
end

def find_term_in_bioportal(term_id)
  response_raw = RestClient.get(Global.config.bp_base_rest_url + Global.config.bp_search_endpoint, {Authorization: "apikey token=#{Global.config.bp_api_key}", params: {q: term_id, require_exact_match: true, no_context: true}})
  term = false

  if response_raw.code === RESPONSE_OK
    response = MultiJson.load(response_raw)

    if response["totalCount"] > 0
      term = response["collection"][0]
    end
  else
    raise Exception, "Unable to query BioPortal #{Global.config.bp_search_endpoint} endpoint. Response code: #{response_raw.code}."
  end

  term
end

def validate_cedar_template(cedar_template_json)
  response_raw = RestClient.post(Global.config.cedar_base_rest_url + Global.config.cedar_validator_endpoint, cedar_template_json, {Authorization: "apiKey #{Global.config.cedar_api_key}", 'Content-Type': 'application/json'})
  {status_code: response_raw.code, response: MultiJson.load(response_raw)}
end

def post_template_to_cedar(cedar_template_json, template_type)
  endpoint = nil

  case template_type
  when 'element'
    endpoint = Global.config.cedar_template_elements_endpoint
  else
    endpoint = Global.config.cedar_templates_endpoint
  end

  cedar_template = MultiJson.load(cedar_template_json)
  cedar_template.delete("@id")
  cedar_template.delete("pav:createdOn")
  cedar_template.delete("pav:createdBy")
  cedar_template.delete("pav:lastUpdatedOn")
  cedar_template.delete("oslc:modifiedBy")
  cedar_template_json = cedar_template.to_json
  response_raw = nil
  resp = nil

  begin
    response_raw = RestClient.post(Global.config.cedar_base_rest_url + endpoint, cedar_template_json, {Authorization: "apiKey #{Global.config.cedar_api_key}", 'Content-Type': 'application/json'})
    resp = {status_code: response_raw.code, response: MultiJson.load(response_raw)}
  rescue Exception => e
    resp = {status_code: e.http_code, response: MultiJson.load(e.http_body)}
  end

  resp
end

def usable_value(val)
  (val["wholeBranch"] && val["wholeBranch"] == "true") || val["exclude"].nil? || val["exclude"] != true
end

def create_cedar_value(orig_value, bp_ontologies, bp_terms)
  cedar_value = false
  not_found = "Not Found"

  if usable_value(orig_value)
    # cache BP entries to reduce number of REST calls
    if bp_terms.key?(orig_value["uri"])
      bp_term = bp_terms[orig_value["uri"]]
    else
      bp_term = find_term_in_bioportal(orig_value["uri"])
      bp_terms[orig_value["uri"]] = bp_term = not_found unless bp_term
    end

    if bp_term != not_found
      ont_acronym = get_acronym_from_id(bp_term["links"]["ontology"])
      cedar_value = {}
      cedar_val = {
        "uri" => orig_value["uri"],
        "source" => "#{bp_ontologies[ont_acronym]} (#{ont_acronym})"
      }

      if orig_value["wholeBranch"] && orig_value["wholeBranch"] == true
        cedar_val.merge!({
          "acronym" => ont_acronym,
          "name" => bp_term["prefLabel"],
          "maxDepth" => 0
        })
        cedar_value["branch"] = cedar_val
      else
        cedar_val.merge!({
          "prefLabel" => bp_term["prefLabel"],
          "label" => bp_term["prefLabel"],
          "type" => "OntologyClass"
        })
        cedar_value["class"] = cedar_val
      end
    end
  end

  cedar_value
end

def enable_uri_value_for_field(cedar_field)
  cedar_field["properties"].delete("@value")
  cedar_field["properties"]["@id"] = {"type" => "string", "format" => "uri"}
  cedar_field
end

def create_cedar_field(orig_field, bp_ontologies, bp_terms)
  base_cedar_field = create_base_entity(orig_field, "field")
  cedar_field = MultiJson.load(base_cedar_field)

  if orig_field["values"] && !orig_field["values"].empty?
    branches = []
    classes = []

    orig_field["values"].each do |original_val|
      converted_val = create_cedar_value(original_val, bp_ontologies, bp_terms)

      if converted_val
        key, value = converted_val.first

        case key
        when "branch"
          branches << value
        when "class"
          classes << value
        end
      end
    end

    vc = cedar_field["_valueConstraints"]
    vc["ontologies"] = []
    vc["valueSets"] = []

    if branches.empty?
      vc["branches"] = []
    else
      vc["branches"] = branches
    end

    if classes.empty?
      vc["classes"] = []
    else
      vc["classes"] = classes
    end

    cedar_field = enable_uri_value_for_field(cedar_field)
  end

  cedar_field
end

def empty_field?(cedar_field)
  vc = cedar_field["_valueConstraints"]
  (vc["ontologies"].nil? || vc["ontologies"].empty?) && \
  (vc["valueSets"].nil? || vc["valueSets"].empty?) && \
  (vc["branches"].nil? || vc["branches"].empty?) && \
  (vc["classes"].nil? || vc["classes"].empty?)
end

def convert_to_uri_field(cedar_field)
  cedar_field["_ui"]["inputType"] = "link"
  enable_uri_value_for_field(cedar_field)
end

def add_field_or_element(orig_field_or_elem, cedar_field_or_elem, cedar_template)
  field_name = cedar_field_or_elem["schema:name"]
  cedar_template["properties"][field_name] = cedar_field_or_elem
  cedar_template["_ui"]["order"] << field_name
  cedar_template["_ui"]["propertyLabels"][field_name] = field_name
  cedar_template["properties"]["@context"]["properties"][field_name] = {"enum" => [orig_field_or_elem["propURI"] || orig_field_or_elem["groupURI"]]}
  cedar_template["properties"]["@context"]["required"] = [] if cedar_template["properties"]["@context"]["required"].nil?
  cedar_template["properties"]["@context"]["required"] << field_name
  cedar_template["required"] << field_name
  cedar_template
end

def add_fields_to_template(orig_fields, cedar_template, bp_ontologies, bp_terms)
  orig_fields = orig_fields.is_a?(Array) ? orig_fields : [orig_fields]

  orig_fields.each do |orig_field|
    cedar_field = create_cedar_field(orig_field, bp_ontologies, bp_terms)
    # create a URI field if no values are provided
    cedar_field = convert_to_uri_field(cedar_field) if empty_field?(cedar_field)
    add_field_or_element(orig_field, cedar_field, cedar_template)
  end

  cedar_template["pav:lastUpdatedOn"] = DateTime.now.strftime
  cedar_template
end

def add_fields_to_element(orig_fields, cedar_element, bp_ontologies, bp_terms)
  add_fields_to_template(orig_fields, cedar_element, bp_ontologies, bp_terms)
end

def create_cedar_element(orig_element, bp_ontologies, bp_terms)
  base_cedar_element = create_base_entity(orig_element, "element")
  cedar_element = MultiJson.load(base_cedar_element)
  orig_element_fields = orig_element["assignments"]
  add_fields_to_element(orig_element_fields, cedar_element, bp_ontologies, bp_terms)
  cedar_element
end

def add_elements_to_template(orig_elements, cedar_template, bp_ontologies, bp_terms)
  orig_elements = orig_elements.is_a?(Array) ? orig_elements : [orig_elements]

  orig_elements.each do |orig_element|
    cedar_element = create_cedar_element(orig_element, bp_ontologies, bp_terms)
    add_field_or_element(orig_element, cedar_element, cedar_template)
  end

  cedar_template["pav:lastUpdatedOn"] = DateTime.now.strftime
  cedar_template
end

def extract_cedar_elements(bao_cedar_template)
  cedar_elements = {}
  base_element_json = File.read(Global.config.cedar_template % {name: "element"})
  base_element = MultiJson.load(base_element_json)
  template_properties = bao_cedar_template["properties"]

  template_properties.each do |key, prop|
    if prop.class == Hash && prop.key?("@id") && prop.key?("@type") && prop["@type"] === base_element["@type"]
      cedar_elements[key] = JSON.pretty_generate(prop)
    end
  end

  cedar_elements
end

def create_cedar_template(orig_template_data, bp_ontologies, bp_terms)
  orig_template_root = orig_template_data["root"]
  base_cedar_template = create_base_entity(orig_template_root, "template")
  cedar_template = MultiJson.load(base_cedar_template)
  orig_template_fields = orig_template_root["assignments"]
  orig_template_elements = orig_template_root["subGroups"]
  add_fields_to_template(orig_template_fields, cedar_template, bp_ontologies, bp_terms) unless orig_template_fields.nil? || orig_template_fields.empty?
  add_elements_to_template(orig_template_elements, cedar_template, bp_ontologies, bp_terms) unless orig_template_elements.nil? || orig_template_elements.empty?
  cedar_template
end

def parse_options()
  options = {}

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

    opts.on('-s', '--source PATH_TO_SOURCE_TEMPLATE', "Optional path to the source template file (default: latest version of template is pulled from #{BAO_GITHUB_PATH})") { |v|
      options[:input_file] = v
    }

    opts.on('-d', '--destination PATH_TO_DESTINATION_TEMPLATE', "Optional path to the destination template file (default: #{Global.config.default_output_file})") { |v|
      options[:output_file] = v
    }

    opts.on('-l', '--log PATH_TO_LOG_FILE', "Optional path to the log file (default: #{Global.config.default_log_file_path})") { |v|
      options[:log_file] = v
    }

    opts.on('-p', '--post-to-cedar [true/false]', 'Post template to CEDAR (if it passes validation) (default: false)') do
      options[:post_to_cedar] = true
    end

    opts.on('-h', '--help', 'Display this screen') do
      puts opts
      exit
    end
  end

  opt_parser.parse!
  options[:input_file] ||= :github
  options[:output_file] ||= Global.config.default_output_file
  options[:log_file] ||= Global.config.default_log_file_path
  options[:post_to_cedar] ||= false
  options[:post_to_cedar] = false unless options[:post_to_cedar] === true
  options
end

def puts_and_log(logger, msg, type='info')
  puts msg
  case type
  when 'warn'
    logger.warn(msg)
  when 'error'
    logger.error(msg)
  else
    logger.info(msg)
  end
end

def main()
  response_post = {status_code: -1}
  bao_full_template = nil
  options = parse_options()

  dirname = File.dirname(options[:log_file])
  FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
  logger = Logger.new(options[:log_file])

  puts_and_log logger, "Generating CEDAR template..."
  puts "Logging output to #{options[:log_file]}"
  puts_and_log logger, "Source template: #{options[:input_file] === :github ? BAO_GITHUB_PATH : options[:input_file]}"
  puts_and_log logger, "Destination template: #{options[:output_file]}"

  time = Benchmark.realtime do
    bp_ontologies = get_bp_ontologies()
    bp_terms = {}

    if options[:input_file] === :github
      puts_and_log logger, "Downloading source template from Github..."
      bao_full_template = get_bao_template_from_github()
      sleep(1)
      puts_and_log logger, "Source template downloaded successfully. Processing..."
    else
      bao_full_template = File.read(options[:input_file])
    end

    bao_data = MultiJson.load(bao_full_template)
    bao_cedar_template = create_cedar_template(bao_data, bp_ontologies, bp_terms)
    bao_cedar_template_json = JSON.pretty_generate(bao_cedar_template)

    File.open(options[:output_file], "w") do |f|
      f.write(bao_cedar_template_json)
    end

    puts_and_log logger, "Completed generating the new template."
    puts_and_log logger, "Running the template through the CEDAR validator..."

    response_validate = validate_cedar_template(bao_cedar_template_json)
    resp_validate = response_validate[:response]

    if resp_validate["validates"] === "true"
      puts_and_log logger, "New template validated successfully."

      if options[:post_to_cedar]
        puts_and_log logger, "Uploading new template to CEDAR..."

        response_post = post_template_to_cedar(bao_cedar_template_json, 'template')

        if response_post[:status_code] === RESPONSE_UPLOAD_SUCCESS
          puts_and_log logger, "New template successfully uploaded to CEDAR."
          puts_and_log logger, "Uploading new template elements to CEDAR..."

          all_elements = extract_cedar_elements(bao_cedar_template)

          all_elements.each do |name, elem|
            response_post = post_template_to_cedar(elem, 'element')

            if response_post[:status_code] === RESPONSE_UPLOAD_SUCCESS
              puts_and_log logger, "Element '#{name}' successfully uploaded to CEDAR..."
            else
              puts_and_log logger, "Element '#{name}' failed CEDAR upload with the following feedback (logged in #{options[:log_file]}):"
              puts_and_log logger, "\nResponse Code: #{response_post[:status_code]}\n#{JSON.pretty_generate(response_post[:response])}"
            end
          end
        else
          puts_and_log logger, "New template failed CEDAR upload with the following feedback (logged in #{options[:log_file]}):"
          puts_and_log logger, "\nResponse Code: #{response_post[:status_code]}\n#{JSON.pretty_generate(response_post[:response])}"
        end
      end
    else
      puts_and_log logger, "New template failed validation with the following feedback (logged in #{options[:log_file]}):"

      unless resp_validate["errors"].empty?
        puts_and_log logger, "\nErrors:   #{JSON.pretty_generate(resp_validate["errors"])}", 'error'
      end

      unless resp_validate["warnings"].empty?
        puts_and_log logger, "\nWarnings: #{JSON.pretty_generate(resp_validate["warnings"])}", 'warn'
      end
      puts
    end
  end

  if response_post[:status_code] === RESPONSE_UPLOAD_SUCCESS
    msg = "Completed template conversion, validation and upload in #{time} seconds."
  else
    msg = "Completed template conversion and validation in #{time} seconds."
  end
  puts_and_log logger, msg
end

main()
