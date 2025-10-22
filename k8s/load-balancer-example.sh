#!/usr/bin/env bash
# https://kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address/
kubectl apply -f k8s/load-balancer-example.yaml
kubectl expose deployment hello-world --type=LoadBalancer --name=my-service
sleep 10
kubectl get services my-service
kubectl describe services my-service
IP=$(kubectl get services my-service --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "curling..."
curl http://"$IP":8080

# Destroy:
#kubectl delete services my-service
#kubectl delete deployment hello-world
