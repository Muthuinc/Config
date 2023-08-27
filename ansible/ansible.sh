#!/bin/bash



a=$(aws ec2 describe-instances --region ap-southeast-2 --filters "Name=tag:Name,Values=app1" --query 'Reservations[].Instances[].PublicIpAddress' --output text)
# store the ip address of the instance

sed -i "s/muthuu/$a/g" inventory.txt
# inserting the dynamically created ip to the inventory.txt file 

