#!/usr/bin/env python3

import time
import jwt
import json
import requests

key_path = '.authorized_key.json'

# Чтение закрытого ключа из JSON-файла
with open(key_path, 'r') as f:
    obj = f.read() 
    obj = json.loads(obj)['authorized_key']
    private_key = obj['private_key']
    key_id = obj['id']
    service_account_id = obj['service_account_id']

sa_key = {
    "id": key_id,
    "service_account_id": service_account_id,
    "private_key": private_key
}

def create_jwt():
    now = int(time.time())
    payload = {
            'aud': 'https://iam.api.cloud.yandex.net/iam/v1/tokens',
            'iss': service_account_id,
            'iat': now,
            'exp': now + 3600
        }

    # Формирование JWT.
    encoded_token = jwt.encode(
        payload,
        private_key,
        algorithm='PS256',
        headers={'kid': key_id}
    )

    #print(encoded_token)

    return encoded_token

def create_iam_token():
    jwt = create_jwt()
    url = 'https://iam.api.cloud.yandex.net/iam/v1/tokens'
    reply = requests.post(url, json = {'jwt': jwt})
    iam_token = reply.json()['iamToken']
    
    #print("Your iam token:")
    print(iam_token)
    return iam_token

create_iam_token()
  

