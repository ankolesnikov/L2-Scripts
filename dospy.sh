#!/bin/bash
# List of servers
SERVERS=(172.18.162.49 172.18.162.64 172.18.162.210 172.18.162.233)
# Choose MOS version from arguments
MOSV=(5.0 5.0.1 5.1 5.1.1 6.0 6.1 7.0)
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
	WCL=$WCL' '$(ssh -qtn ${SRV} 'virsh list | grep running | wc -l')
done

SERVER=${SERVERS[$(python -c "arr='$WCL'.split(); print arr.index(sorted(arr)[0])" )]}

if ssh -qtn $SERVER stat $ISO_PATH \> /dev/null 2\>\&1; then
    echo "+++ ISO Found"
    if [[ 0 < $(ssh -qtn $SERVER $DOSPY list | grep $ENV_NAME | wc -l) ]]; then
        echo "!!! Env" $ENV_NAME "on the server" $SERVER "exist !!!"
        exit 1
    else
        echo "+++ Server" $SERVER "Env" $ENV_NAME
    fi
else
echo "!!! ISO not found !!!"
    exit 1
fi

# Start Env creating
ssh -qtn $SERVER $DOSPY 'create \
	--node-count '$NODE_COUNT' \
	--vcpu '$VCPU_COUNT' \
	--ram '$RAM_SIZE' \
	--admin-vcpu '$ADMIN_VCPU_COUNT' \
	--admin-ram '$ADMIN_RAM_SIZE' \
	--net-pool '$NET_POOL' \
	--iso-path '$ISO_PATH' '\
	$ENV_NAME

# Start Fuel Master Node installation
ssh -qtn $SERVER $DOSPY admin-setup $ENV_NAME

# Print Admin and Public Networks CIDR
ADM_NET=$(ssh -qtn $SERVER $DOSPY net-list $ENV_NAME | grep admin)
PUB_NET=$(ssh -qtn $SERVER $DOSPY net-list $ENV_NAME | grep public)
echo "+++ Env created on the server" $SERVER
echo "+++ Network" $ADM_NET
echo "+++ Network" $PUB_NET
echo "+++ Fuel Master IP is "$(echo $ADM_NET | tr -s \  \\t | cut -f 2 | sed 's/.....$//')".2"
read -p "Press any key to continue or CTRL-C if no tunnel needed"

# Start tunnel to host
echo "Press CTRL-C for terminate the tunnel"
sshuttle -r $SERVER $(echo $NET_POOL | sed 's/...$//') &

# Delete Env after all
#ssh -tn $SERVER $DOSPY erase $ENV_NAME
