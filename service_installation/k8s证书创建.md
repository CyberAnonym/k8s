```

参考地址：http://blog.csdn.net/u010278923/article/details/71126246
安装kubernetes最麻烦的地方应该就是证书的认证，由于kubernetes1.6后加的RBAC，使得配置更加麻烦了，先是制作证书，如果你对openssl或者easyrsa熟悉的话，同理可以替换，先安装cfssl。
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl

wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x cfssl-certinfo_linux-amd64
sudo mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo

1.生成ca证书
创建ca-config.json
vim ca-config.json
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
创建ca-csr.json
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

生成证书

cfssl gencert -initca ca-csr.json | cfssljson -bare ca


2.生成kubernetes证书
创建kubernetes-csr.json
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "172.18.0.1",
    "192.168.2.31",
    "u1.shenmin.com",
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
这个里面配置的IP，是使用该证书机器的IP，根据自己的环境填写其中172.18.0.1是kubernetes自带的service，执行生成命令：
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes


3.创建admin证书
创建admin-csr.json
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
生成证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin

ls admin*


4.创建proxy证书
创建kube-proxy-csr.json
vim kube-proxy-csr.json
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
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy

5.秘钥分发
mkdir -p /etc/kubernetes/ssl
cp *.pem /etc/kubernetes/ssl

查看验证证书
openssl x509  -noout -text -in  kubernetes.pem
for i in u1 u2 u3;do ssh  $i 'mkdir -p /etc/kubernetes/ssl';done
for i in u1 u2 u3;do scp *.pem  $i:/etc/kubernetes/ssl;done
```
