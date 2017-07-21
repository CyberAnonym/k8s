# etcd服务器集群安装文档
参考：http://rootsongjc.github.io/blogs/kubernetes-etcd-ha-config/
#### 定义服务器环境
export ETCD_NAME=u1.shenmin.com 
export INTERNAL_IP=192.168.2.31  
#### 创建相关目录  
```
sudo mkdir -p /var/lib/etcd 
cat > etcd.service <<EOF  
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

mv etcd.service /lib/systemd/system/etcd.service  
systemctl daemon-reload  
systemctl start etcd  

检查ETCD是否正常运行  
在任一 kubernetes master 机器上执行如下命令：  
$ etcdctl \  a
  --ca-file=/etc/kubernetes/ssl/ca.pem \  
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \  
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \  
 --endpoint=https://u1.shenmin.com:2379  cluster-health  
 
 如果是要为k8s提供服务，这里我们尝试为k8s创建一个目录  
 
etcdctl   --ca-file=/etc/kubernetes/ssl/ca.pem   --cert-file=/etc/kubernetes/ssl/kubernetes.pem   --key-file=/etc/kubernetes/ssl/kubernetes-key.pem --endpoint=https://u1.shenmin.com:2379  mk /coreos.com/network/config '{"Network":"192.168.0.0/16", "Backend": {"Type": "vxlan"}}'
```
