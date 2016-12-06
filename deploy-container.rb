#!/usr/bin/env ruby
require_relative './lib/azure/common-deploy'

GROUP_NAME  = 'confoo-containers'
site_name   = 'confoo123'
container   = 'devigned/confoo:v1.0.1'

template = File.read(File.expand_path(File.join(__dir__, './container-template.json')))
deployer = Azure::Deployer.new
parameters = {
    server_farm_name: 'confoo-rb-sf-01',
    site_name:        site_name,
    doc_db_name:      'confoo-con02-mongo'
}
# deployer.put_deployment(GROUP_NAME, template, parameters)

app_settings = deployer.web.sites.list_site_app_settings(GROUP_NAME, site_name)
app_settings.properties['DOCKER_CUSTOM_IMAGE_NAME'] = container

deployer.web.sites.update_site_app_settings(GROUP_NAME, site_name, app_settings)
deployer.web.sites.restart_site(GROUP_NAME, site_name)

