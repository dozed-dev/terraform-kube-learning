#!/usr/bin/env bash
echo '{"kind":"ExecCredential","apiVersion":"client.authentication.k8s.io/v1beta1","spec":{"interactive":false},"status":{"expirationTimestamp":"2081-08-13T10:19:06Z","token":"'"$YC_TOKEN"'"}}'
