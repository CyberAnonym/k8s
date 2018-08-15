# flanneld的安装

**这里我们已经下载了软件flannel-0.5.5-linux-amd64.tar.gz ，并解压得到了我们的flanneld 文件。</br>**
```bash
tar xf /samba/packages/linux/flannel-v0.8.0-linux-amd64.tar.gz -C /tmp/
cd /tmp/
for i in k8s1 k8s2 k8s3;do scp flanneld $i:/opt/bin/;done
```
**如果要直接启动flannel，可以执行下面的命令。**   </br>
/opt/bin/flanneld --etcd-endpoints="https://k8s1.alv.pub:2379,https://k8s2.alv.pub:2379,https://k8s3.alv.pub:2379" --iface=192.168.127.94 --ip-masq -etcd-cafile=/etc/kubernetes/ssl/ca.pem </br>

这样也可以启动成功。（注意启动的命令后面不要加空格）

这里我们用systemd来管理flanneld， </br>
```bash
IFACE=192.168.127.94
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
  --etcd-endpoints="https://k8s1.alv.pub:2379,https://k8s2.alv.pub:2379,https://k8s3.alv.pub:2379" \\
  --iface=$IFACE \\
   --etcd-cafile=/etc/kubernetes/ssl/ca.pem \\
  --ip-masq

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

然后启动flannel。
systemctl daemon-reload
systemctl start flanneld.service 
```

然后我们需要让docker的网段与flanneld的一样，执行下面的命令。   
```bash
wget -q -O - https://raw.githubusercontent.com/AlvinWanCN/scripts/master/shell/k8s/syncFlannelToDocker.sh|bash
```
