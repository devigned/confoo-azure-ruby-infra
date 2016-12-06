
require_relative '../../lib/azure/common-deploy'

public_ip_name = 'rb-public-ip'
deployer = Azure::Deployer.new
resource_group = deployer.resource.resource_groups.get('simple-rb-vm')
p_ip = deployer.network.public_ipaddresses.get(resource_group.name, public_ip_name)

# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

server p_ip.ip_address, user: 'deploy', roles: %w{app db web}
