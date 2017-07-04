#!/bin/bash
#######################################################
# $Name:         deploy-cbppro-business-k8s-v1.0.sh
# $Version:      v1.0
# $Function:     deploy k8s of cbppro service modules.
# $Author:       Leiting Liu
# $organization: leiting.red
# $Create Date:  2017-06-16
# $Description:  You know what i mean,hehe
# $LogFile: cbppro log in the local path /data2/k8springcloud/ of every module.
#######################################################

##common modules
#kubectl create -f eureka-v1.yaml
#kubectl create -f configcenter-v1.yaml

##business modules
kubectl create -f zuul-v1.yaml
kubectl create -f authority-v1.yaml
kubectl create -f filesystem-v1.yaml
kubectl create -f dynamic-v1.yaml
kubectl create -f kc-v1.yaml
kubectl create -f food-v1.yaml
kubectl create -f mc-v1.yaml
kubectl create -f message-v1.yaml

