#!/bin/sh
#
# 此脚本负责刷新k8s证书,以及导出p12文件使用

# =====================================================

WORK_DIR='~/'
SYS_DT="$(date +%F-%T)"
RESIDUAL_TIME="$(kubeadm certs check-expiration|sed -n '6,6p'|awk   '{print $7}'| tr -cd '[0-9]')"

exiterr()  { echo "Error: $1" >&2; exit 1; }

update_k8s_cer(){
    if [ $RESIDUAL_TIME -gt 30 ]; then
        exiterr "距离过期还有30天以上,请不要刷新证书"
    fi
    # TODO: 这块最后要改成刷新
    kubeadm certs renew all
    
    # 拷贝证书
    cp -n /etc/kubernetes/admin.conf /tmp/.kube/config

    # 重启 kubelet服务
    systemctl restart kubelet

    # 重启kube-apiserver、kube-controller-manager、kube-scheduler的三个pod
    docker ps |grep kube-apiserver|grep -v pause|awk '{print $1}'|xargs -i docker restart {}
    docker ps |grep kube-controller-manage|grep -v pause|awk '{print $1}'|xargs -i docker restart {}
    docker ps |grep kube-scheduler|grep -v pause|awk '{print $1}'|xargs -i docker restart {}

    cat <<EOF

    ================================================

    证书刷新成功

    预计1年后过期请放心使用

    ================================================
EOF

}

write_jenkins_p12(){

    awk '/certificate-authority-data:/{print $2}' /etc/kubernetes/admin.conf | base64 -d > /tmp/kube-ca.crt
    grep '^users' /etc/kubernetes/admin.conf -A 100|grep 'name: kubernetes-admin' -A 3|awk '/client-certificate-data:/ {print $2}' | base64 -d > /tmp/kube-client.crt
    grep '^users' /etc/kubernetes/admin.conf -A 100|grep 'name: kubernetes-admin' -A 3|awk '/client-key-data:/ {print $2}' | base64 -d > /tmp/kube-client.key
    #创建证书，创建证书需要设置密码，设置的密码不要忘记
    echo "创建证书，创建证书需要设置密码，设置的密码不要忘记"
    openssl pkcs12 -export -out /tmp/kube-cert.pfx -inkey /tmp/kube-client.key -in /tmp/kube-client.crt -certfile /tmp/kube-ca.crt
    cat <<EOF

    ================================================

    请将/tmp/kube-cert.pfx文件拷回本地，并上传Jenkins。

    ================================================
EOF
}

read -p "请问你是期望刷新证书【1】，还是导出jenkins使用的p12文件【2】？" userinput

if [ -n "$userinput" ]
then
    if [ $userinput -eq "1" ]
    then
        update_k8s_cer "$@"
    else
        write_jenkins_p12 "$@"
    fi
else
    exiterr "输入错误"
fi

exit 0