require 'azure_mgmt_resources'
require 'azure_mgmt_network'
require 'azure_mgmt_storage'
require 'azure_mgmt_compute'
require 'azure_mgmt_web'
require 'securerandom'

WEST_US = 'westus'

StorageModels = Azure::ARM::Storage::Models
NetworkModels = Azure::ARM::Network::Models
ComputeModels = Azure::ARM::Compute::Models
ResourceModels = Azure::ARM::Resources::Models
WebModels = Azure::ARM::Web::Models

module Azure
  class Deployer

    attr_reader :network, :storage, :resource, :compute, :web

    def initialize
      subscription_id = ENV['AZURE_SUBSCRIPTION_ID']
      provider = MsRestAzure::ApplicationTokenProvider.new(
          ENV['AZURE_TENANT_ID'],
          ENV['AZURE_CLIENT_ID'],
          ENV['AZURE_CLIENT_SECRET'])
      credentials = MsRest::TokenCredentials.new(provider)
      @resource = Azure::ARM::Resources::ResourceManagementClient.new(credentials)
      @network = Azure::ARM::Network::NetworkManagementClient.new(credentials)
      @storage = Azure::ARM::Storage::StorageManagementClient.new(credentials)
      @compute = Azure::ARM::Compute::ComputeManagementClient.new(credentials)
      @web = Azure::ARM::Web::WebSiteManagementClient.new(credentials)
      [@resource, @network, @storage, @compute, @web].each do |client|
        client.subscription_id=subscription_id
      end
    end

    def put_deployment(name, template, parameters = {})
      location = parameters.delete(:location) || WEST_US

      # ensure the resource group is created
      params = ResourceModels::ResourceGroup.new.tap do |rg|
        rg.location = location
      end
      group = resource.resource_groups.create_or_update(name, params)

      # build the deployment from a json file template from parameters
      deployment = ResourceModels::Deployment.new
      deployment.properties = ResourceModels::DeploymentProperties.new
      deployment.properties.template = JSON.parse(template)
      deployment.properties.mode = ResourceModels::DeploymentMode::Incremental

      # build the deployment template parameters from Hash to {key: {value: value}} format
      if parameters.delete(:add_ssh)
        parameters.merge!(ssh_key: default_pub_key)
      end
      deployment.properties.parameters = Hash[*parameters.map { |k, v| [k, {value: v}] }.flatten]

      # put the deployment to the resource group
      puts "Deploying template to group #{group.name}"
      resource.deployments.create_or_update(group.name, 'confoo-deploy', deployment)
    end

    def put_resource_group(name, location=WEST_US)
      puts "Putting resource group named #{name} in #{location}"
      resource_group_params = ResourceModels::ResourceGroup.new.tap do |rg|
        rg.location = location
      end

      self.resource.resource_groups.create_or_update(name, resource_group_params)
    end

    def put_storage_account(group, name, location=WEST_US)
      puts "Putting storage account named #{name} in #{location}"
      storage_create_params = StorageModels::StorageAccountCreateParameters.new.tap do |account|
        account.location = location
        account.sku = StorageModels::Sku.new.tap do |sku|
          sku.name = StorageModels::SkuName::PremiumLRS
          sku.tier = StorageModels::SkuTier::Premium
        end
        account.kind = StorageModels::Kind::Storage
        account.encryption = StorageModels::Encryption.new.tap do |encrypt|
          encrypt.services = StorageModels::EncryptionServices.new.tap do |services|
            services.blob = StorageModels::EncryptionService.new.tap do |service|
              service.enabled = false
            end
          end
        end
      end
      self.storage.storage_accounts.create(group.name, name, storage_create_params)
    end

    def put_basic_vnet(group, name, location=WEST_US)
      puts "Putting vnet named #{name} in #{location}"
      vnet_create_params = NetworkModels::VirtualNetwork.new.tap do |vnet|
        vnet.location = location
        vnet.address_space = NetworkModels::AddressSpace.new.tap do |addr_space|
          addr_space.address_prefixes = ['10.0.0.0/16']
        end
        vnet.dhcp_options = NetworkModels::DhcpOptions.new.tap do |dhcp|
          dhcp.dns_servers = ['8.8.8.8']
        end
        vnet.subnets = [
            NetworkModels::Subnet.new.tap do |subnet|
              subnet.name = 'basic-vnet'
              subnet.address_prefix = '10.0.0.0/24'
            end
        ]
      end
      self.network.virtual_networks.create_or_update(group.name, name, vnet_create_params)
    end

    def put_public_ip(group, name, dns_label, location=WEST_US)
      puts "Putting public ip named #{name} in #{location} w/ dns label #{dns_label}"
      public_ip_params = NetworkModels::PublicIPAddress.new.tap do |ip|
        ip.location = location
        ip.public_ipallocation_method = NetworkModels::IPAllocationMethod::Dynamic
        ip.dns_settings = NetworkModels::PublicIPAddressDnsSettings.new.tap do |dns|
          dns.domain_name_label = dns_label
        end
      end
      self.network.public_ipaddresses.create_or_update(group.name, name, public_ip_params)
    end

    def vm_exists?(group, name)
      self.compute.virtual_machines.list(group.name).any? { |vm| vm.name == name }
    end

    # Create a Virtual Machine and return it
    def put_vm(group, name, storage_acct, subnet, public_ip, location=WEST_US)
      puts "Putting vm named #{name} in #{location}"
      nic = self.network.network_interfaces.create_or_update(
          group.name,
          "nic-#{name}",
          NetworkModels::NetworkInterface.new.tap do |interface|
            interface.location = WEST_US
            interface.ip_configurations = [
                NetworkModels::NetworkInterfaceIPConfiguration.new.tap do |nic_conf|
                  nic_conf.name = "nic-#{name}"
                  nic_conf.private_ipallocation_method = NetworkModels::IPAllocationMethod::Dynamic
                  nic_conf.subnet = subnet
                  nic_conf.public_ipaddress = public_ip
                end
            ]
          end
      )

      vm_create_params = ComputeModels::VirtualMachine.new.tap do |vm|
        vm.location = location
        vm.os_profile = ComputeModels::OSProfile.new.tap do |os_profile|
          os_profile.computer_name = name
          os_profile.admin_username = 'deploy'
          os_profile.admin_password = 'aslu23r09qoIFnqoiwnfawr!!'
        end

        vm.storage_profile = ComputeModels::StorageProfile.new.tap do |store_profile|
          store_profile.image_reference = ComputeModels::ImageReference.new.tap do |ref|
            ref.publisher = 'canonical'
            ref.offer = 'UbuntuServer'
            ref.sku = '16.04.0-LTS'
            ref.version = 'latest'
          end
          store_profile.os_disk = ComputeModels::OSDisk.new.tap do |os_disk|
            os_disk.name = "os-disk-#{name}"
            os_disk.caching = ComputeModels::CachingTypes::None
            os_disk.create_option = ComputeModels::DiskCreateOptionTypes::FromImage
            os_disk.vhd = ComputeModels::VirtualHardDisk.new.tap do |vhd|
              vhd.uri = "https://#{storage_acct.name}.blob.core.windows.net/confoo/#{name}.vhd"
            end
          end
        end

        vm.hardware_profile = ComputeModels::HardwareProfile.new.tap do |hardware|
          hardware.vm_size = ComputeModels::VirtualMachineSizeTypes::StandardDS2V2
        end

        vm.network_profile = ComputeModels::NetworkProfile.new.tap do |net_profile|
          net_profile.network_interfaces = [
              ComputeModels::NetworkInterfaceReference.new.tap do |ref|
                ref.id = nic.id
                ref.primary = true
              end
          ]
        end
      end

      key_data = default_pub_key
      vm_create_params.os_profile.linux_configuration = ComputeModels::LinuxConfiguration.new.tap do |linux|
        linux.disable_password_authentication = true
        linux.ssh = ComputeModels::SshConfiguration.new.tap do |ssh_config|
          ssh_config.public_keys = [
              ComputeModels::SshPublicKey.new.tap do |pub_key|
                pub_key.key_data = key_data
                pub_key.path = '/home/deploy/.ssh/authorized_keys'
              end
          ]
        end
      end

      self.compute.virtual_machines.create_or_update(group.name, name, vm_create_params)
    end

    def default_pub_key
      ssh_pub_location = File.expand_path('~/.ssh/id_rsa.pub')
      if File.exists? ssh_pub_location
        File.read(ssh_pub_location)
      else
        nil
      end
    end

    def provision(remote)
      ssh = "ssh #{remote}"

      sudo_script = <<-SCRIPT
apt-get update;
apt-get install -y nginx nodejs mongodb-server git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties libffi-dev;
      SCRIPT

      script = <<-SCRIPT
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3;
curl -sSL https://get.rvm.io | bash -s stable --rails;
rvm;
rvm install 2.3.0;
sudo systemctl start mongodb
      SCRIPT

      puts ssh
      while `#{ssh} "sh -c 'echo \\"foo\\"'"`.strip != 'foo'
        sleep(5)
        puts 'waiting for ssh to come up'
      end
      puts 'Ensuring OS dependencies are installed'
      puts `#{ssh} "sudo sh -c '#{sudo_script}'"`
      puts `#{ssh} "sh -c $'#{script}'"`
      puts `scp ./config/local_env.yml #{remote}:local_env.yml`
    end

  end
end