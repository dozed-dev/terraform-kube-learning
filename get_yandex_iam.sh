#!/usr/bin/env bash
set -eu

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

repo="$(dirname -- "$0")"
pushd "$repo" > /dev/null

init_python
get_token

popd > /dev/null

