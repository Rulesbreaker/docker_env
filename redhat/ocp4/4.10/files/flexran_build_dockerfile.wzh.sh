#!/bin/bash
local_path=$PWD
tmp_path=flexran_build
dockerimagename=flexran.docker.registry/flexran_vdu
http_proxy=`env|grep http_proxy |awk -F '=' '{print $2}'`
https_proxy=`env|grep https_proxy|awk -F '=' '{print $2}'`
rm -rf $tmp_path
rm -rf bin/nr5g/gnb/l1/l1app
echo "Note please first build dpdk!!!"
source ./set_env_var.sh
./flexran_build.sh $*
if [ ! -f "bin/nr5g/gnb/l1/l1app" ]; then
   echo "flexran build failed , docker image not build!!"
   exit -1
else
   echo "flexran build success"
fi
echo "build xran"
cd framework/enhanced_bbupool/build/
make clean
make all
cd $local_path
cd xran
./build.sh xclean
./build.sh SAMPLEAPP

cd $local_path
mkdir $tmp_path
mkdir $tmp_path/flexran
echo "copy flexran bin"
cp -r bin $tmp_path/flexran/
cp -r flexran_build.sh $tmp_path/flexran/
cp -r libs $tmp_path/flexran/
cp -r sdk $tmp_path/flexran/
#cp -r tests flexran_build/flexran/
cp -r wls_mod $tmp_path/flexran/
cp -r set_env_var.sh $tmp_path/flexran/
cp -r xran $tmp_path/flexran/
#cd flexran_build/flexran/
#add remove flexran source code
rm -rf $tmp_path/flexran/sdk/test
rm -rf $tmp_path/flexran/sdk/source
rm -rf $tmp_path/flexran/tests
rm -rf $tmp_path/flexran/source
rm -rf $tmp_path/flexran/bin/lte
rm -rf $tmp_path/flexran/libs/ferrybridge
rm -rf $tmp_path/flexran/framework
#rm -rf $tmp_path/flexran/xran

#touch dockerfile
#cd $local_path

cat << EOF > $tmp_path/local.repo
[localrepo]
name=LocalRepo
baseurl=ftp://10.88.0.1/dnf/extensions
enabled=1
gpgcheck=0
EOF

if [ -z $http_proxy ];then
    cat > $tmp_path/Dockerfile << 'EOF'
FROM registry.access.redhat.com/ubi8/ubi:8.4

RUN dnf repolist
RUN sed -i 's|enabled=1|enabled=0|g' /etc/yum/pluginconf.d/subscription-manager.conf
RUN sed -i 's|$releasever|8.4|g' /etc/yum.repos.d/redhat.repo
RUN sed -i '/codeready-builder-for-rhel-8-x86_64-rpms/,/\[/ s/enabled = 0/enabled = 1/' /etc/yum.repos.d/redhat.repo
RUN mv -f /etc/yum.repos.d/ubi.repo /etc/yum.repos.d/ubi.repo.bak

COPY local.repo /etc/yum.repos.d/local.repo

RUN yum update -y
RUN yum install -y libhugetlbfs-utils libhugetlbfs-devel libhugetlbfs numactl-devel pciutils libaio libaio-devel net-tools libpcap kernel-rt-core kernel-rt-devel kernel-rt-modules kernel-rt-modules-extra kernel-headers libhugetlbfs-devel zlib-devel numactl-devel cmake gcc gcc-c++

WORKDIR /root/
COPY flexran ./flexran
RUN rm -rf /var/yum/cache/*
EOF
else
    cat > $tmp_path/Dockerfile << 'EOF'
FROM registry.access.redhat.com/ubi8/ubi:8.4
ENV http_proxy $http_proxy
ENV https_proxy $https_proxy

RUN dnf repolist
RUN sed -i 's|enabled=1|enabled=0|g' /etc/yum/pluginconf.d/subscription-manager.conf
RUN sed -i 's|$releasever|8.4|g' /etc/yum.repos.d/redhat.repo
RUN sed -i '/codeready-builder-for-rhel-8-x86_64-rpms/,/\[/ s/enabled = 0/enabled = 1/' /etc/yum.repos.d/redhat.repo
RUN mv -f /etc/yum.repos.d/ubi.repo /etc/yum.repos.d/ubi.repo.bak

COPY local.repo /etc/yum.repos.d/local.repo

RUN yum update -y
RUN yum install -y libhugetlbfs-utils libhugetlbfs-devel libhugetlbfs numactl-devel pciutils libaio libaio-devel net-tools libpcap kernel-rt-core kernel-rt-devel kernel-rt-modules kernel-rt-modules-extra kernel-headers libhugetlbfs-devel zlib-devel numactl-devel cmake gcc gcc-c++

WORKDIR /root/
COPY flexran ./flexran
RUN rm -rf /var/yum/cache/*
EOF
fi

#add tests docker images

#build flexran docker image
cd $tmp_path
docker build --squash -t $dockerimagename .
#delete tmp path flexran_build
cd $local_path
rm -rf $tmp_path

