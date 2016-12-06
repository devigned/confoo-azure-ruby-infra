#! /bin/bash


### This is not intended to work as an individual script. It's simply as a guide for running all of the cmds

### Simple VM Deployment
bundle exec ruby deploy-vm.rb
bundle exec cap simple deploy:initial


### Template Deployment
bundle exec ruby deploy-vm-template.rb
bundle exec cap template deploy:initial
### Extend the template deployment with DocumentDB
### Just drop in the new resource and redeploy the template
bundle exec ruby deploy-vm-template.rb
bundle exec cap template deploy
### SSH into the machine and look at `cat apps/appname/current/log/production.log`


### Container Deployment
docker ps
bundle exec ruby deploy-container.rb