#! /bin/bash


### This is not intended to work as an individual script. It's simply as a guide for running all of the cmds

### Simple VM Deployment
bundle exec ruby deploy-vm.rb
bundle exec cap simple deploy:initial


### Template Deployment
bundle exec ruby deploy-vm-template.rb
bundle exec cap template deploy:initial
### Extend the template deployment with DocumentDB
### Just drop in the new resource, uncomment local_env.yml and redeploy the template
bundle exec ruby deploy-vm-template.rb
bundle exec cap template deploy
### SSH into the machine and look at `cat apps/appname/current/log/production.log`


### Container Deployment
docker ps
ID=$(docker run -e "PORT=$PORT" -p $PORT:$PORT -d devigned/confoo:v1.0.0)
docker stop $ID
https://localhost:8080
bundle exec ruby deploy-container.rb
docker build -t devigned/confoo:v1.0.1 .
ID=$(docker run -e "PORT=$PORT" -p $PORT:$PORT -d devigned/confoo:v1.0.1)
docker push devigned/confoo:v1.0.1
bundle exec ruby deploy-container.rb