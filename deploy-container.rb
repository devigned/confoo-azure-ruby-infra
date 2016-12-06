#!/usr/bin/env ruby
require_relative './lib/azure/common-deploy'

GROUP_NAME = 'confoo-containers'

template = File.read(File.expand_path(File.join(__dir__, './container-template.json')))
deployer = Azure::Deployer.new
parameters = {
    server_farm_name: 'confoo-rb-sf',
    site_name:        'confoo123',
    doc_db_name:      'confoo-con-mongo'
}
# deployer.put_deployment(GROUP_NAME, template, parameters)

app_settings = deployer.web.sites.list_site_app_settings(GROUP_NAME, parameters[:site_name])
app_settings.properties['DOCKER_CUSTOM_IMAGE_NAME'] = 'devigned/docker-ruby-hello-world:latest'

deployer.web.sites.update_site_app_settings(GROUP_NAME, parameters[:site_name], app_settings)

