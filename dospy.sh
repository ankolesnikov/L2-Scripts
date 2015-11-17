#!/bin/bash
# List of servers
SERVERS=(172.18.162.49 172.18.162.64 172.18.162.210 172.18.162.233)
# Choose MOS version from arguments
MOSV=(4.0 4.1.1 5.0 5.0.1 5.1 5.1.1 6.0 6.1 7.0)
case "$1" in
	-h|--help)
	echo "$0 --mos | --MOS | -mos | -MOS version"
	echo "Avaliable version of Mirantis OpenStack -" ${MOSV[*]}
	exit 0
	;;
	-MOS|-mos|--MOS|--mos)
	if [[ ${MOSV[@]} =~ "$2" ]]; then
		MOS="$2"
		echo "You have selected MOS ver." $MOS
	else
		echo "$2 is not avaliable"
		echo "Please select MOS version from" ${MOSV[*]}
		exit 1
	fi
	;;
	*)
	echo "$0 --mos | --MOS | -mos | -MOS version"
	echo "Avaliable version of Mirantis OpenStack -" ${MOSV[*]}
	exit 1
	;;
esac

DOSPY=/home/jenkins/venv-devops-2.9/bin/dos.py
ISO_PATH=/var/tmp/ISO/MirantisOpenStack-$MOS.iso
VCPU_COUNT=2
NODE_COUNT=5
RAM_SIZE=4096
NET_POOL=10.51.0.0/16:24
#ADMIN_DISK_SIZE=
ADMIN_RAM_SIZE=4096
ADMIN_VCPU_COUNT=2
#SECOND_DISK_SIZE=
#THIRD_DISK_SIZE=
ENV_NAME=$(whoami)-$MOS

# Looking for server with smallest load
for SRV in ${SERVERS[@]}; do
	WCL=$WCL' '$(ssh -tn ${SRV} 'virsh list | grep running | wc -l')
done

SERVER=${SERVERS[$(python -c "arr='$WCL'.split(); print arr.index(sorted(arr)[0])" )]}

# Start Env creating
ssh -tn $SERVER $DOSPY 'create \
--node-count '$NODE_COUNT' \
--vcpu '$VCPU_COUNT' \
--ram '$RAM_SIZE' \
--admin-vcpu '$ADMIN_VCPU_COUNT' \
--admin-ram '$ADMIN_RAM_SIZE' \
--net-pool '$NET_POOL' \
--iso-path '$ISO_PATH' '\
$ENV_NAME

# Start Fuel Master Node installation
ssh -tn $SERVER $DOSPY admin-setup $ENV_NAME

# Print Admin and Public Networks CIDR
ADM_NET=$(ssh -tn $SERVER $DOSPY net-list $ENV_NAME | grep admin)
PUB_NET=$(ssh -tn $SERVER $DOSPY net-list $ENV_NAME | grep public)
echo "ADM_NET" $ADM_NET
echo "PUB_NET" $PUB_NET
echo "Env created on the server" $SERVER
echo "Your Fuel Master IP is x.x.x.2 in net-pool" $NET_POOL 
read -p "Press any key to continue or CTRL-C if no tunnel needed"

# Start tunnel to host
echo "Press CTRL-C for terminate the tunnel"
sshuttle -r $SERVER $(echo $NET_POOL | sed 's/...$//')

# Delete Env after all
#ssh -tn $SERVER $DOSPY erase $ENV_NAME
