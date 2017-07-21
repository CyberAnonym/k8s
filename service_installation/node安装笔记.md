参考文档： http://blog.csdn.net/u010278923/article/details/71126246

(journalctl -u kubelet -f  #查看日志)
```
1. 角色绑定
在master上面做角色绑定
kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap


2. 配置kubeconfig
Node 节点上的 kubelet、kube-proxy 需要通过 kubeconfig 获取master证书等信息。



(下面)
【
kubectl config set-credentials kubelet \
  --client-certificate=/etc/kubernetes/ssl/kubelet.crt \
  --client-key=/etc/kubernetes/ssl/kubelet.key \
  --embed-certs=true \
  --kubeconfig=kubelet.kubeconfig


kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet \
  --kubeconfig=kubelet.kubeconfig

kubectl config use-context default --kubeconfig=kubelet.kubeconfig

】
2.1 bootstrap.kubeconfig

cd /etc/kubernetes/
export BOOTSTRAP_TOKEN=1ac6fd59506cba11ffc4a74d98f5df9e
export KUBE_APISERVER="https://192.168.2.31:6443"

 kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig
 # 设置客户端认证参数
 kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig
 # 设置上下文参数
 kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig
 # 设置默认上下文
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

2.2 kube-proxy.kubeconfig
创建kube-proxy.kubeconfig
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig
# 设置客户端认证参数


kubectl config set-credentials kube-proxy \
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
# 设置上下文参数
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
# 设置默认上下文
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

3. kubelet
配置文件
cat /etc/kubernetes/kubelet
###
# kubernetes kubelet (minion) config

# The address for the info server to serve on (set to 0.0.0.0 or "" for all interfaces)
KUBELET_ADDRESS="--address=0.0.0.0"

# The port for the info server to serve on
# KUBELET_PORT="--port=10250"

# You may leave this blank to use the actual hostname
KUBELET_HOSTNAME="--hostname-override=u1"

# location of the api-server
#KUBELET_API_SERVER="--api-servers=http://192.168.2.31:8080"

# pod infrastructure container
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest"

# Add your own!
KUBELET_ARGS=" --cluster-dns=172.18.8.8 --cluster-domain=cluster.local --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig --kubeconfig=/etc/kubernetes/kubelet.kubeconfig --require-kubeconfig --cert-dir=/etc/kubernetes/ssl"

服务文件
vim /lib/systemd/system/kubelet.service
[root@slave1 kubernetes]# cat /lib/systemd/system/kubelet.service

[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/kubelet
ExecStart=/opt/bin/kubelet \
        $KUBE_LOGTOSTDERR \
        $KUBE_LOG_LEVEL \
        $KUBELET_ADDRESS \
        $KUBELET_HOSTNAME \
        $KUBE_ALLOW_PRIV \
        $KUBELET_ARGS
Restart=on-failure

[Install]
WantedBy=multi-user.target





4. kube-proxy

配置文件
#cat /etc/kubernetes/proxy 

# kubernetes proxy config
# default config should be adequate
# Add your own!
KUBE_PROXY_ARGS="--proxy-mode=iptables --cluster-cidr=192.168.0.0/16"

vim /lib/systemd/system/kube-proxy.service 
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/proxy
ExecStart=/opt/bin/kube-proxy \
        $KUBE_LOGTOSTDERR \
        $KUBE_LOG_LEVEL \
        $KUBE_MASTER \
        $KUBE_PROXY_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target




启动kubelet 
测试的时候，直接使用命令也可以，使用如下命令。
/opt/bin/kubelet --logtostderr=true --v=0 --address=192.168.2.31 --hostname-override=u1 --allow-privileged=tru --cluster-dns=172.18.8.8 --cluster-domain=cluster.local --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig --kubeconfig=/etc/kubernetes/kubelet.kubeconfig --require-kubeconfig --cert-dir=/etc/kubernetes/ssl

然后并不能注册成功，因为还需要master授权CSR 
查看未授权的 CSR 请求
$ kubectl get csr
NAME        AGE       REQUESTOR           CONDITION
csr-2b308   4m        kubelet-bootstrap   Pending
$ kubectl get nodes
No resources found.
通过 CSR 请求
$ kubectl certificate approve csr-2b308
certificatesigningrequest "csr-2b308" approved
$ kubectl get nodes
NAME        STATUS    AGE       VERSION
10.64.3.7   Ready     49m       v1.6.1

然后kubelet 那边就注册成功了。
```
