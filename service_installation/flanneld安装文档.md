# flanneld的安装

**这里我们已经下载了软件flannel-0.5.5-linux-amd64.tar.gz ，并解压得到了我们的flanneld 文件。</br>**
root@u1:~# ll /samba/packages/linux/flannel-0.5.5-linux-amd64.tar.gz </br>
-rw-r--r--+ 1 99 99 3489977 May 12 10:48 /samba/packages/linux/flannel-0.5.5-linux-amd64.tar.gz</br>


root@u1:~# ll /opt/bin/flanneld </br>
-rwxr-xr-x 1 root root 16581152 Jun 22 15:46 /opt/bin/flanneld</br>

**如果要直接启动flannel，可以执行下面的命令。**   </br>
/opt/bin/flanneld --etcd-endpoints="https://u1.shenmin.com:2379,https://u2.shenmin.com:2379,https://u3.shenmin.com:2379" --iface=192.168.2.31 --ip-masq -etcd-cafile=/etc/kubernetes/ssl/ca.pem </br>

这样也可以启动成功。（注意启动的命令后面不要加空格）

这里我们用systemd来管理flanneld， </br>

vim /lib/systemd/system/flanneld.service</br>
[Unit]</br>
Description=Flanneld overlay address etcd agent</br>
After=network.target</br>
After=network-online.target</br>
Wants=network-online.target</br>
After=etcd.service</br>
Before=docker.service</br>

[Service]</br>
Type=notify</br>
ExecStart=/opt/bin/flanneld \ </br>
  --etcd-endpoints="https://u1.shenmin.com:2379,https://u2.shenmin.com:2379,https://u3.shenmin.com:2379" \ </br>
  --iface=192.168.2.31 \ </br>
  --ip-masq \ </br>
  --etcd-cafile=/etc/kubernetes/ssl/ca.pem</br>
Restart=on-failure</br>

[Install]</br>
WantedBy=multi-user.target</br>
