#!/bin/bash
set -euo pipefail
export AWS_REGION=eu-central-1

SUBNET_ID="subnet-0a48dad47a9f318d9" # ЗАМЕНИ НА ID ТВОЕЙ ПОДСЕТИ public-a
RT_ID="rtb-0ede1e9165d2acab3"      # ЗАМЕНИ НА ID ТВОЕЙ ТАБЛИЦЫ private-rt

echo "1. Выделение Elastic IP..."
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=timecapsule-dev-nat-a-eip},{Key=Project,Value=timecapsule},{Key=Environment,Value=dev},{Key=Owner,Value=student},{Key=Lab,Value=3}]' --query 'AllocationId' --output text)

echo "2. Создание NAT Gateway..."
NAT_ID=$(aws ec2 create-nat-gateway --subnet-id $SUBNET_ID --allocation-id $EIP_ALLOC_ID --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=timecapsule-dev-nat-a},{Key=Project,Value=timecapsule},{Key=Environment,Value=dev},{Key=Owner,Value=student},{Key=Lab,Value=3}]' --query 'NatGateway.NatGatewayId' --output text)

echo "3. Ожидание доступности NAT Gateway (2-3 минуты)..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID

echo "4. Добавление маршрута в private-rt..."
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_ID > /dev/null

echo "5. Сохранение ID в файл..."
echo "EIP_ALLOC_ID=$EIP_ALLOC_ID" > .nat_ids
echo "NAT_ID=$NAT_ID" >> .nat_ids
echo "NAT Gateway $NAT_ID успешно поднят."