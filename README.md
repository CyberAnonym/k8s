1, [安装环境](#安装环境)  <br>
2, [创建证书](#创建证书)  <br>
3, [配置kubeconfig](#配置kubeconfig)  <br>
4, [安装配置etcd服务](#安装etcd服务)<br>
5, [安装配置flanneld服务](#安装配置flanneld服务)  <br>
6, [安装k8s master](#安装k8s master)<br>
7, [安装k8s node](#安装k8s node)<br>
# 安装环境：  
三台服务器，一台master，两台node  ,三台服务器之间已做了ssh免密码登录认证。

**三台服务器上都存在的配置**
```bash
cat /etc/hosts
127.0.0.1	localhost
192.168.2.31 u1.shenmin.com u1
192.168.2.32 u2.shenmin.com u2
192.168.2.33 u3.shenmin.com u3
```
**master服务器信息** <br>
Hostname: os1.shenmin.com<br>
IP: 192.168.2.31<br>
**node1服务器信息**  
Hostname: os2.shenmin.com  
IP: 192.168.2.32  
**node2服务器信息**  
Hostname: os3.shenmin.com  
IP: 192.168.2.33  


# 创建证书
创建证书部分参考地址：http://blog.csdn.net/u010278923/article/details/71082349
```shell
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl

wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x cfssl-certinfo_linux-amd64
sudo mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
```
创建ca-config.json<br>
vim ca-config.json
```json
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "8760h"
      }
    }
  }
}

```
创建ca-csr.json<br>
vim ca-csr.json
```json
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
```
生成证书
```shell
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```
查看ca证书
```shell
ls ca*
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```
生成kubernetes证书<br>
创建kubernetes-csr.json<br>
vim kubernetes-csr.json
```json
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "192.168.2.31",
    "192.168.2.32",
    "192.168.2.33",
    "172.18.0.1",
    "u1",
    "u2",
    "u3"
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
```
**创建admin证书**<br>
创建admin-csr.json<br>
vim admin-csr.json
```json
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
```
**生成证书**<br>
```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
ls admin*
```

**创建proxy证书**<br>
创建kube-proxy-csr.json<br>
vim kube-proxy-csr.json
```json
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
```
**生成证书**<br>
```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
```

秘钥分发
```bash
for i in u1 u2 u3;do ssh  $i 'mkdir -p /etc/kubernetes/ssl';done
for i in u1 u2 u3;do scp *.pem  $i:/etc/kubernetes/ssl;done
```
查看验证证书
openssl x509  -noout -text -in  kubernetes.pem

# 配置kubeconfig
创建 TLS Bootstrapping Token<br>
Token auth file<br>
Token可以是任意的包涵128 bit的字符串，可以使用安全的随机数发生器生成。<br>
```bash
export BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
```
后三行是一句，直接复制上面的脚本运行即可。<br>
将token.csv发到所有机器（Master 和 Node）的 /etc/kubernetes/ 目录。<br>
```bash
cp token.csv /etc/kubernetes/
```
##### 创建 Kubelet Bootstrapping Kubeconfig 文件<br>
```bash
cd /etc/kubernetes
export KUBE_APISERVER="https://192.168.2.31:6443
# 设置集群参数
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
```
- --embed-certs 为 true 时表示将 certificate-authority 证书写入到生成的 bootstrap.kubeconfig 文件中；
- 设置客户端认证参数时没有指定秘钥和证书，后续由 kube-apiserver 自动生成；
##### 创建Kube-Proxy Kubeconfig 文件
```
export KUBE_APISERVER="https://192.168.2.31:6443"
# 设置集群参数
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
  ```
- 设置集群参数和客户端认证参数时 --embed-certs 都为 true，这会将 certificate-authority、client-certificate 和 client-key 指向的证书文件内容写入到生成的 kube-proxy.kubeconfig 文件中；
- kube-proxy.pem 证书中 CN 为 system:kube-proxy，kube-apiserver 预定义的 RoleBinding cluster-admin 将User system:kube-proxy 与 Role system:node-proxier 绑定，该 Role 授予了调用 kube-apiserver Proxy 相关 API 的权限；

##### 分发 Kubeconfig 文件
将两个 kubeconfig 文件分发到所有 Node 机器的 /etc/kubernetes/ 目录<br>
for i in u1 u2 u3;do scp bootstrap.kubeconfig kube-proxy.kubeconfig token.csv $i:/etc/kubernetes/;done
# 安装etcd服务
**下载etcd**
etcd 的github地址：https://github.com/coreos/etcd/releases  
[这里我们下载3.1.10版本](https://github.com/coreos/etcd/releases/download/v3.1.10/etcd-v3.1.10-linux-amd64.tar.gz)
```bash
wget https://github.com/coreos/etcd/releases/download/v3.1.10/etcd-v3.1.10-linux-amd64.tar.gz
#创建用于存放服务文件的的目录
for i in u1 u2 u3;do ssh $i 'mkdir -p /opt/bin';done
#解压etcd安装包到/tmp目录
tar xf etcd-v3.1.10-linux-amd64.tar.gz -C /tmp/
#将etcd的运行文件发到相应的服务器上去
for i in u1 u2 u3;do scp /tmp/etcd-v3.1.10-linux-amd64/etcd* $i:/opt/bin/;done
```
##### 定义服务器环境
- 以下配置在三台服务器上都做，ETCD_NAME和IP分别写每台服务器自己的。
```shell
export ETCD_NAME=u1.shenmin.com 
export INTERNAL_IP=192.168.2.31  
```
##### 创建相关目录  
```bash
sudo mkdir -p /var/lib/etcd
```
##### 创建启动启动脚本
```bash
cat > /lib/systemd/system/etcd.service  <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=-/etc/etcd/etcd.conf
ExecStart=/opt/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \\
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \\
  --peer-cert-file=/etc/kubernetes/ssl/kubernetes.pem \\
  --peer-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \\
  --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster u1.shenmin.com=https://u1.shenmin.com:2380,u2.shenmin.com=https://u2.shenmin.com:2380,u3.shenmin.com=https://u3.shenmin.com:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]  
WantedBy=multi-user.target  
EOF
```
- 重新加载服务并启动
```bash
systemctl daemon-reload
systemctl start etcd  
```
- 在三台服务器都配置、启动好了etcd之后，我们可以来检查一下ETCD是否正常运行。

检查ETCD是否正常运行，在任一 kubernetes master 机器上执行如下命令：<br>
```bash
/opt/bin/etcdctl \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
 --endpoint=https://u1.shenmin.com:2379  cluster-health
```
 - 接下来要为k8s提供服务，这里我们尝试为k8s创建一个目录 <br>
```bash
/opt/bin/etcdctl \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  --endpoint=https://u1.shenmin.com:2379,https://u2.shenmin.com:2379,https://u3.shenmin.com:2379 \
  mk /coreos.com/network/config '{"Network":"192.168.0.0/16", "Backend": {"Type": "vxlan"}}'
```
# 安装配置flanneld服务

flannel的历史版本在这里 https://github.com/coreos/flannel/releases <br>
这里我们下载的是0.8.0版本。<br>
```bash
 wget https://github.com/coreos/flannel/releases/download/v0.8.0/flannel-v0.8.0-linux-amd64.tar.gz
 ```
 - 解压包，并将flanneld传到指定的服务器指定目录
 ```
 tar xf flannel-v0.8.0-linux-amd64.tar.gz -C /tmp/
 cd /tmp/
for i in u1 u2 u3;do scp flanneld $i:/opt/bin/;done
```
这里我们用systemd来管理flanneld， </br>
```bash
IFACE=192.168.2.31
cat > /lib/systemd/system/flanneld.service << EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
ExecStart=/opt/bin/flanneld \\
  --etcd-endpoints="https://u1.shenmin.com:2379,https://u2.shenmin.com:2379,https://u3.shenmin.com:2379" \\
  --iface=$IFACE \\
   --etcd-cafile=/etc/kubernetes/ssl/ca.pem \\
  --ip-masq

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
```
- 然后启动flannel。
```bash
systemctl daemon-reload
systemctl start flanneld.service 
```
- 然后我们需要让docker的网段与flanneld的一样，执行下面的命令。
```bash
wget -q -O - https://raw.githubusercontent.com/AlvinWanCN/scripts/master/shell/k8s/syncFlannelToDocker.sh|bash
```
# 安装k8s maste
- 编写配置文件
- 公共配置文件<br>

```bash
vim /etc/kubernetes/config
###
# kubernetes system config
#
# The following values are used to configure various aspects of all
# kubernetes services, including
#
#   kube-apiserver.service
#   kube-controller-manager.service
#   kube-scheduler.service
#   kubelet.service
#   kube-proxy.service
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=true"

# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=0"

# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=false"

# How the controller-manager, scheduler, and proxy find the apiserver
KUBE_MASTER="--master=http://192.168.2.31:8080"
```
- kube-apiserver的配置文件
```bash
vim /etc/kubernetes/apiserver
###
## kubernetes system config
##
## The following values are used to configure the kube-apiserver
##
#
## The address on the local server to listen to.
#KUBE_API_ADDRESS="--insecure-bind-address=sz-pg-oam-docker-test-001.tendcloud.com"
KUBE_API_ADDRESS="--advertise-address=192.168.2.31 --bind-address=192.168.2.31 --insecure-bind-address=0.0.0.0"
#
## The port on the local server to listen on.
#KUBE_API_PORT="--port=8080"
#
## Port minions listen on
#KUBELET_PORT="--kubelet-port=10250"
#
## Comma separated list of nodes in the etcd cluster
KUBE_ETCD_SERVERS="--etcd-servers=https://u1.shenmin.com:2379,https://u2.shenmin.com:2379,https://u3.shenmin.com:2379"
#
## Address range to use for services
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=172.18.0.0/16"
#
## default admission control policies
KUBE_ADMISSION_CONTROL="--admission-control=ServiceAccount,NamespaceLifecycle,NamespaceExists,LimitRanger,ResourceQuota"
#
## Add your own!
KUBE_API_ARGS="--authorization-mode=RBAC --runtime-config=rbac.authorization.k8s.io/v1beta1 --kubelet-https=true --experimental-bootstrap-token-auth --token-auth-file=/etc/kubernetes/token.csv --service-node-port-range=30000-32767 --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem --client-ca-file=/etc/kubernetes/ssl/ca.pem --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem --etcd-cafile=/etc/kubernetes/ssl/ca.pem --etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem --etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem --enable-swagger-ui=true --apiserver-count=3 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/var/lib/audit.log --event-ttl=1h"
```
- kube-apiserver的启动文件
```bash
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
After=etcd.service

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/apiserver
User=root
ExecStart=/opt/bin/kube-apiserver \
        $KUBE_LOGTOSTDERR \
        $KUBE_LOG_LEVEL \
        $KUBE_ETCD_SERVERS \
        $KUBE_API_ADDRESS \
        $KUBE_API_PORT \
        $KUBELET_PORT \
        $KUBE_ALLOW_PRIV \
        $KUBE_SERVICE_ADDRESSES \
        $KUBE_ADMISSION_CONTROL \
        $KUBE_API_ARGS
Restart=on-failure
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
- kube-controller-manager的配置文件
```bash
vim /etc/kubernetes/controller-manager 
###
# The following values are used to configure the kubernetes controller-manager

# defaults from config and apiserver should be adequate

# Add your own!
KUBE_CONTROLLER_MANAGER_ARGS="--allocate-node-cidrs=true --cluster-cidr=192.168.0.0/16  --service-cluster-ip-range=172.18.0.0/16 --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem --service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem --root-ca-file=/etc/kubernetes/ssl/ca.pem"
```
- kube-controller-manager的启动文件
```bash
vim /lib/systemd/system/kube-controller-manager.service 
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/controller-manager
User=root
ExecStart=/opt/bin/kube-controller-manager \
        $KUBE_LOGTOSTDERR \
        $KUBE_LOG_LEVEL \
        $KUBE_MASTER \
        $KUBE_CONTROLLER_MANAGER_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
- kube-scheduler的配置文件
```bash
vim /etc/kubernetes/scheduler
###
# kubernetes scheduler config

# default config should be adequate

# Add your own!
KUBE_SCHEDULER_ARGS="--port=10251"
```
- kube-scheduler的启动文件
```bash
vim /lib/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler Plugin
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/scheduler
User=root
ExecStart=/usr/bin/kube-scheduler \
        $KUBE_LOGTOSTDERR \
        $KUBE_LOG_LEVEL \
        $KUBE_MASTER \
        $KUBE_SCHEDULER_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
- 下载并解压软件到指定位置
#下载软件
 ```
 wget https://github.com/kubernetes/kubernetes/releases/download/v1.6.2/kubernetes.tar.gz
 tar xf kubernetes.tar.gz
./kubernetes/cluster/get-kube-binaries.sh
y
cd /tmp/kubernetes/server/
tar xf kubernetes-server-linux-amd64.tar.gz
cd kubernetes/server/bin/
cp kube-apiserver kube-controller-manager kube-scheduler /opt/bin/
for i in u1 u2 u3;do scp kubelet kubectl kube-proxy $i:/opt/bin;done
```
- 启动服务
```
systemctl daemon-reload
systemctl enable kube-apiserver
systemctl start kube-apiserver
systemctl enable kube-controller-manager
systemctl start kube-controller-manager
systemctl enable kube-scheduler
systemctl start kube-scheduler
```
- 确认各个组件的状态是否都是正常运行。
```bash
root@u1:~# kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok                   
controller-manager   Healthy   ok                   
etcd-1               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"
```
# 安装k8s node

- 角色绑定
#现在要去master上做角色绑定<br>
```bash
kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap
```
- 编写公共配置文件
```bash
vim /etc/kubernetes/config
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=true"

# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=0"

# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=true"

# How the controller-manager, scheduler, and proxy find the apiserver
KUBE_MASTER="--master=https://192.168.2.31:6443"
```
- 编写kubelet的配置文件
#不同的node上在IP和NAME上都写自己的。<br>
```bash
cat > /etc/kubernetes/kubelet <<EOF
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
EOF
```
- 创建一个kubelet的目录
```bash
mkdir -p /var/lib/kubelet
```
- 编写kubelet服务启动文件
```bash
vim /lib/systemd/system/kubelet.service
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
```
- 编写kube-proxy的配置文件
```bash
vim /etc/kubernetes/proxy
# kubernetes proxy config
# default config should be adequate
# Add your own!
KUBE_PROXY_ARGS="--bind-address=192.168.2.32 --hostname-override=u2 --proxy-mode=iptables --cluster-cidr=192.168.0.0/16 --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig
```
- 编写kube-proxy启动文件
```bash
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
        $KUBE_HOSTNAME \
        $KUBE_PROXY_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
- 启动kubelet
```bash
systemctl daemon-reload
systemctl start kubelet
```
- 做完上面的这一操作，要去maser上授权这个kubelet访问
做完这一步要去master节点上授权<br>
下面是示例<br>
```bash
$ kubectl get csr
NAME        AGE       REQUESTOR           CONDITION
csr-2b308   4m        kubelet-bootstrap   Pending
$ kubectl get nodes
No resources found.
#通过 CSR 请求
$ kubectl certificate approve csr-2b308
certificatesigningrequest "csr-2b308" approved
$ kubectl get nodes
NAME        STATUS    AGE       VERSION
10.64.3.7   Ready     49m       v1.6.1
#然后kubelet 那边就注册成功了。
```
- 然后启动kube-proxy
```bash
systemctl start kube-proxy 
```
