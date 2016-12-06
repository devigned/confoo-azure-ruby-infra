require_relative '../../lib/azure/common-deploy'

public_ip_name = 'confoo-tmpl-pip'
deployer = Azure::Deployer.new
resource_group = deployer.resource.resource_groups.get('template-rb')
p_ip = deployer.network.public_ipaddresses.get(resource_group.name, public_ip_name)

server p_ip.ip_address, user: 'deploy', roles: %w{app db web}