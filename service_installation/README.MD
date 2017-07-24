1, [安装环境](#安装环境)  
2, [创建证书](#创建证书)  
3, [配置kubeconfig](#配置kubeconfig)  
4, [安装配置etcd服务](#安装配置etcd服务)  
5, [安装配置flanneld服务](#安装配置flanneld服务)

# 安装环境：  
三台服务器，一台master，两台node  ,三台服务器之间已做了ssh免密码登录认证。

**三台服务器上都存在的配置**
```bash
#cat /etc/hosts
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
```bash
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

