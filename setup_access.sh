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
export YC_CLOUD_ID="$(get_jq_secret YC_CLOUD_ID)"
export YC_FOLDER_ID="$(get_jq_secret YC_FOLDER_ID)"
export ACCESS_KEY="$(get_jq_secret ACCESS_KEY)"
export SECRET_KEY="$(get_jq_secret SECRET_KEY)"
