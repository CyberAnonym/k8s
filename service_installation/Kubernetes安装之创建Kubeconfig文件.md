```
curl: http://rootsongjc.github.io/blogs/kubernetes-create-kubeconfig/

前言
这是和我一步步部署kubernetes集群项目((fork自opsnull))中的一篇文章，下文是结合我之前部署kubernetes的过程产生的kuberentes环境，生成kubeconfig文件的过程。kubelet、kube-proxy 等 Node 机器上的进程与 Master 机器的 kube-apiserver 进程通信时需要认证和授权； kubernetes 1.4 开始支持由 kube-apiserver 为客户端生成 TLS 证书的 TLS Bootstrapping 功能，这样就不需要为每个客户端生成证书了；该功能当前仅支持为 kubelet 生成证书。
创建 TLS Bootstrapping Token
Token auth file
Token可以是任意的包涵128 bit的字符串，可以使用安全的随机数发生器生成。
export BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

后三行是一句，直接复制上面的脚本运行即可。
将token.csv发到所有机器（Master 和 Node）的 /etc/kubernetes/ 目录。
$cp token.csv /etc/kubernetes/

创建 Kubelet Bootstrapping Kubeconfig 文件
$ cd /etc/kubernetes
$ export KUBE_APISERVER="https://192.168.127.94:6443
$ # 设置集群参数
$ kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig
$ # 设置客户端认证参数
$ kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig
$ # 设置上下文参数
$ kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig
$ # 设置默认上下文
$ kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

  ● --embed-certs 为 true 时表示将 certificate-authority 证书写入到生成的 bootstrap.kubeconfig 文件中；
  ● 设置客户端认证参数时没有指定秘钥和证书，后续由 kube-apiserver 自动生成；
创建 Kube-Proxy Kubeconfig 文件
$ export KUBE_APISERVER="https://192.168.127.94:6443"
$ # 设置集群参数
$ kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig
$ # 设置客户端认证参数
$ kubectl config set-credentials kube-proxy \
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
$ # 设置上下文参数
$ kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
$ # 设置默认上下文
$ kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

  ● 设置集群参数和客户端认证参数时 --embed-certs 都为 true，这会将 certificate-authority、client-certificate 和 client-key 指向的证书文件内容写入到生成的 kube-proxy.kubeconfig 文件中；
  ● kube-proxy.pem 证书中 CN 为 system:kube-proxy，kube-apiserver 预定义的 RoleBinding cluster-admin 将User system:kube-proxy 与 Role system:node-proxier 绑定，该 Role 授予了调用 kube-apiserver Proxy 相关 API 的权限；
分发 Kubeconfig 文件
将两个 kubeconfig 文件分发到所有 Node 机器的 /etc/kubernetes/ 目录
$ cp bootstrap.kubeconfig kube-proxy.kubeconfig /etc/kubernetes/

root@k8s1:/samba/packages/linux/docker_images/config# ll
total 6144
drwxr-xr-x+ 2 99 99    0 Jul 20 19:24 ./
drwx------+ 6 99 99    0 Jul 19 14:27 ../
-rw-r--r--+ 1 99 99 1710 Jul 20 19:23 apiserver
-rw-------+ 1 99 99 2174 Jul 19 18:17 bootstrap.kubeconfig
-rw-r--r--+ 1 99 99  733 Jul 19 18:10 config
-rw-r--r--+ 1 99 99  934 Jul 20 19:24 kubelet
-rw-------+ 1 99 99 6284 Jul 19 20:13 kube-proxy.kubeconfig
-rw-r--r--+ 1 99 99   84 Jul 19 18:09 token.csv
root@k8s1:/samba/packages/linux/docker_images/config# for i in k8s1 k8s2 k8s3;do scp *  $i:/etc/kubernetes/ ';done


```
