#!/bin/bash


kubens argocd

secret="your-password"
echo "ArgoCD initial password: $secret"

argocd login localhost:8080 --username admin --password $secret

argocd cluster add default