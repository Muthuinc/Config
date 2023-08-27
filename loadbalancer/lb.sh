#!/bin/bash

b=$(aws ec2 describe-instances --region ap-southeast-2 --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=app1" --query "Reservations[*].Instances[*].InstanceId" --output text)

c=$(aws ec2 describe-vpcs --region ap-southeast-2 --filters "Name=tag:Name,Values=abigaile" --query "Vpcs[0].VpcId" --output text)

d=$(aws ec2 describe-subnets --region ap-southeast-2 --filters "Name=tag:Name,Values=Pub1" --query "Subnets[*].SubnetId"  --output text)

e=$(aws ec2 describe-subnets --region ap-southeast-2 --filters "Name=tag:Name,Values=Pub2" --query "Subnets[*].SubnetId"  --output text)

sed -i "s/instance/"$b"/g" variables.tf

sed -i "s/instanceid/"$c"/g" variables.tf

sed -i "s/sub1/"$d"/g" variables.tf

sed -i "s/sub2/"$e"/g" variables.tf

terraform init && terraform apply --auto-approve

