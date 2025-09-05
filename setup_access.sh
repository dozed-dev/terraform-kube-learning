#!/usr/bin/bash

init_python() {
  python -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt > /dev/null
  deactivate
}

get_token() {
  source .venv/bin/activate
  ./get_ya_iam.py
  deactivate
}

get_jq_secret() {
  jq --raw-output ".env.$1" < .authorized_key.json
}

if [ ! -d ".venv" ]; then
  init_python
fi

export YC_TOKEN="$(get_token)"
vars=(YC_CLOUD_ID YC_FOLDER_ID ACCESS_KEY SECRET_KEY)
for var in "${vars[@]}"; do
  get_jq_secret $var | read -r ${var?}
  export ${var?}
done
