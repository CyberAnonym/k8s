1,  [安装环境](#安装环境)

# 安装环境：  
三台服务器，一台master，两台node  

**master服务器信息**  
Hostname: os1.shenmin.com  
IP: 192.168.2.31  
```bash
#cat /etc/hosts
127.0.0.1	localhost
192.168.2.31 u1.shenmin.com u1
192.168.2.32 u2.shenmin.com u2
192.168.2.33 u3.shenmin.com u3
```
**node1服务器信息**  
Hostname: os2.shenmin.com  
IP: 192.168.2.32  
```bash
#cat /etc/hosts
127.0.0.1	localhost
192.168.2.31 u1.shenmin.com u1
192.168.2.32 u2.shenmin.com u2
192.168.2.33 u3.shenmin.com u3
```
**node2服务器信息**  

Hostname: os3.shenmin.com  
IP: 192.168.2.33  
```bash
#cat /etc/hosts
127.0.0.1	localhost
192.168.2.31 u1.shenmin.com u1
192.168.2.32 u2.shenmin.com u2
192.168.2.33 u3.shenmin.com u3
```

# 安装etcd服务
**下载etcd**
etcd 的github地址：https://github.com/coreos/etcd/releases  
[这里我们下载3.1.10版本](https://github.com/coreos/etcd/releases/download/v3.1.10/etcd-v3.1.10-linux-amd64.tar.gz)
https://github.com/coreos/etcd/releases/download/v3.1.10/etcd-v3.1.10-linux-amd64.tar.gz
