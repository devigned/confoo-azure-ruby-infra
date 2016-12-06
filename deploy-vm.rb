#!/usr/bin/env ruby

require_relative './lib/azure/common-deploy'

GROUP_NAME      = 'simple-rb-vm'
vm_name         = 'simple-rb-vm'
public_ip_name  = 'rb-public-ip'
storage_name    = 'confoorbvmstor11'

deployer = Azure::Deployer.new
resource_group = deployer.put_resource_group(GROUP_NAME)

if !deployer.vm_exists?(resource_group, vm_name)
  storage_account = deployer.put_storage_account(resource_group, storage_name)
  vnet = deployer.put_basic_vnet(resource_group, 'rb-vm-vnet')
  public_ip = deployer.put_public_ip(resource_group, public_ip_name, 'simple-rb-vm')
  vm = deployer.put_vm(resource_group, vm_name, storage_account, vnet.subnets[0], public_ip)
else
  vm = deployer.compute.virtual_machines.get(resource_group.name, vm_name)
  public_ip = deployer.network.public_ipaddresses.get(resource_group.name, public_ip_name)
end
remote =  "#{vm.os_profile.admin_username}@#{public_ip.ip_address}"

deployer.provision(remote)



