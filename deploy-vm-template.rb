#!/usr/bin/env ruby
require_relative './lib/azure/common-deploy'

GROUP_NAME = 'template-rb'

template = File.read(File.expand_path(File.join(__dir__, './simple-vm-template.json')))
deployer = Azure::Deployer.new
parameters = {
    vm_username:          'deploy',
    vm_password:          'alskdfjlkasjfnewoifn@232DSDa',  # not used password auth is turned off
    vm_name:              'confoo-tmpl-vm',
    storage_account_name: 'confootmplstor01',
    pip_name:             'confoo-tmpl-pip'
}
deployer.put_deployment(GROUP_NAME, template, parameters)
public_ip = deployer.network.public_ipaddresses.get(GROUP_NAME, parameters[:pip_name])
deployer.provision("#{parameters[:vm_username]}@#{public_ip.ip_address}")