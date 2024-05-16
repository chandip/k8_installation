# dns for the controller and the worker node

printf "\n192.168.100.161 master-node\n192.168.4.82 node-1\n192.168.4.83 node-2\n192.168.4.84 node-3\n\n" >> /etc/hosts
cat /etc/hosts

# bridging net firewall
printf "overlay\nbr_netfilter\n" >> /etc/modules-load.d/containerd.conf
#overlay --> often used in containerization environment, as it provides a union filesystem, which is crucial component for container runtime environments like docker and containerd
# br_netfilter --> network filtering with the linux kernel's bridge firewalling capabilities, which is essential for managing network traffic in containerized environment
#by adding thestr to the modules to the containerd config file, this will auto load when system boot

# network ip forward 
printf "net.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\n" >> /etc/sysctl.d/99-kubernetes-cri.conf
#1) net.bridge.bridge-nf-call-iptables = 1 --> this setting enables iptables to process bridged traffic. in kubernetes it allows iptables to filter network traffic for pods and services.
#2) net.ipv4.ip_forward = 1 --> this setting enables IP forwarding, allowing packets to be forwarded between network interfaces on the system. In bkubernetes cluster, this is often necessary for routing traffic between pods and external networks.
#3) net.bridge.bridge-nf-call-ip6tables = 1 --> similar to the first settingbut for IPv6 traffic. it enables ip6tables to process bridged IPv6 traffic


sysctl --system
# download containerd service for linux deamon
#It manages the complete container lifecycle of its host system, including container image distribution, storage, and runtime execution.
#wget https://github.com/containerd/containerd/releases/download/v1.6.16/containerd-1.6.16-linux-amd64.tar.gz -P /tmp/

#new version of containerd (CRI)
wget https://github.com/containerd/containerd/releases/download/v2.0.0-rc.0/containerd-2.0.0-rc.0-linux-amd64.tar.gz -P /tmp/


#tar Cxzvf /usr/local /tmp/containerd-1.6.16-linux-amd64.tar.gz
tar Cxzvf /usr/local /tmp/containerd-2.0.0-rc.0-linux-amd64.tar.gz

# download predefine service containerd service (service definition file)
#which is used to manage the containerd daemon on a Linux system. systemd is a system and service manager for Linux operating systems, and it's commonly used to start, stop, and manage services.
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -P /etc/systemd/system/


#In summary, the containerd-1.6.16-linux-amd64.tar.gz provides the actual containerd runtime binary package,
# while the containerd.service provides a systemd service file to manage the containerd daemon once it's installed on a Linux system



systemctl daemon-reload
systemctl enable --now containerd


# runc its part of the containerd runtime
#wget https://github.com/opencontainers/runc/releases/download/v1.1.4/runc.amd64 -P /tmp/

wget https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64 -P /tmp/

#When you download and execute this runc.amd64 binary on a compatible Linux system,
# it provides the runc command-line interface, which allows you to interact with
# OCI-compliant container images and containers. With runc, you can start, stop,
# and manage containers directly, without needing a higher-level container engine like Docker.

install -m 755 /tmp/runc.amd64 /usr/local/sbin/runc

wget https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz -P /tmp/

mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin /tmp/cni-plugins-linux-amd64-v1.2.0.tgz

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

swapoff -a

apt-get install vim

vim /etc/containerd/config.toml
--> edit
	--> SystemdCgroup = true

systemctl restart containerd

vi /etc/fstab
	comment the swap line out



apt-get update

apt-get install -y apt-transport-https ca-certificates curl


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

reboot

apt-get install kubelet kubeadm kubectl

# hold the updates when system upgrade
apt-mark hold kubelet kubeadm kubectl

free -m


___ only for the control plane install ______
# calico is the default network for the k8s
kubeadm init --pod-network-cidr 10.10.0.0/16 --kubernetes-version 1.29.3 --node-name master-node

exit

# work as regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

############### getCNI ____calico_________
kubectl get nodes

adding Calico 3.25 CNI
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml

# edit the file to add cidr that was first created
wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
# edit
kubectl apply -f custom-resources.yaml


kubeadm token create --print-join-command

kubectl label node k8s-worker1 node-role.kubernetes.io/worker=worker

scp -r ~/.kube/config madzones@192.168.100.169:~/.kube/config
scp -r ~/.kube/config madzones@192.168.100.173:~/.kube/config

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.4.85:6443 --token d61d46.d3p9u7d7np535r7q \
        --discovery-token-ca-cert-hash sha256:6d688273502601a06fc22d21045ffbe223e7904d254cb8cf3c29d33a4168c203