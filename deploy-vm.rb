#!/usr/bin/env ruby

require_relative './lib/azure/common-deploy'

GROUP_NAME = 'simple-rb-vm'
vm_name = 'simple-rb-vm'
public_ip_name = 'rb-public-ip'

deployer = Azure::Deployer.new
resource_group = deployer.put_resource_group(GROUP_NAME)

if !deployer.vm_exists?(resource_group, vm_name)
  storage_account = deployer.put_storage_account(resource_group, 'confoorbvmstor')
  vnet = deployer.put_basic_vnet(resource_group, 'rb-vm-vnet')
  public_ip = deployer.put_public_ip(resource_group, public_ip_name, 'simple-rb-vm')
  vm = deployer.put_vm(resource_group, vm_name, storage_account, vnet.subnets[0], public_ip)
else
  vm = deployer.compute.virtual_machines.get(resource_group.name, vm_name)
  public_ip = deployer.network.public_ipaddresses.get(resource_group.name, public_ip_name)
end
ssh =  "ssh #{vm.os_profile.admin_username}@#{public_ip.ip_address}"

sudo_script = <<-SCRIPT
apt-get update;
apt-get install -y nginx nodejs git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties libffi-dev;
SCRIPT

script = <<-SCRIPT
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3;
curl -sSL https://get.rvm.io | bash -s stable --rails;
rvm;
rvm install 2.3.3;
SCRIPT


puts ssh
puts 'Ensuring nginx is installed'
puts `#{ssh} "sudo sh -c '#{sudo_script}'"`
puts `#{ssh} "sh -c '#{script}'"`
# puts 'Ensuring RVM is installed'
# puts `#{ssh} "sh -c 'gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 & curl -sSL https://get.rvm.io | bash -s stable'"`
# puts `#{ssh} "sh -c 'source ~/.rvm/scripts/rvm & rvm requirements & rvm install 2.3.3'"`
