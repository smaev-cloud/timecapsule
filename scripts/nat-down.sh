#!/bin/bash
set -euo pipefail
export AWS_REGION=eu-central-1

RT_ID="rtb-0ede1e9165d2acab3" # ЗАМЕНИ НА ID ТВОЕЙ ТАБЛИЦЫ private-rt

if [ ! -f .nat_ids ]; then
    echo "Файл .nat_ids не найден!"
    exit 1
fi
source .nat_ids

echo "1. Удаление маршрута..."
aws ec2 delete-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 || true

echo "2. Удаление NAT Gateway..."
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID > /dev/null

echo "3. Ожидание удаления NAT Gateway (около 2 минут)..."
aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_ID

echo "4. Освобождение Elastic IP..."
sleep 10 # Короткая пауза для AWS
RETRY=0
while ! aws ec2 release-address --allocation-id $EIP_ALLOC_ID 2>/dev/null; do
    RETRY=$((RETRY+1))
    if [ $RETRY -ge 5 ]; then
        echo "Не удалось освободить IP. Удали вручную."
        exit 1
    fi
    echo "Адрес еще занят шлюзом. Ждем 15 секунд..."
    sleep 15
done

rm .nat_ids
echo "NAT Gateway удален, IP успешно освобожден."