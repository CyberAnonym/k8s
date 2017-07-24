1, [安装环境](#安装环境)  
2, [创建证书](#创建证书)  
3, [配置kubeconfig](#配置kubeconfig)  
4, [安装配置etcd服务](#安装配置etcd服务) 
5, [安装配置flanneld服务](#安装配置flanneld服务)  

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

# 创建kubeconfig文件
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
创建 Kubelet Bootstrapping Kubeconfig 文件<br>
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

