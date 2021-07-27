#!/bin/bash
set -xue

# git history
# v3.5.0
# ...
# v3.0.0
# ...
NEW_BEHAVIOR=337ef64ed # The network split breaks the follower who dont see the leader, the leader cannot be re-elected
OLD_BEHAVIOR=fb64c8ccf # The leader is successfully re-elected after the network split
# ...
# v3.0.0-beta.0
# ...
# v2.2.4

# Let's say there are three nodes X Y Z, node Z is the current cluster leader.
# If at this time there is a network split between nodes Y and Z or X and Z,
# after the commit #337ef64ed, the follower who see all other nodes cannot be elected as the leader,

COMMIT=${1:-$OLD_BEHAVIOR}

if ! grep docker /proc/1/cgroup; then
    docker build -t issue-8129 - <<-EOF
    FROM ubuntu:latest
    RUN apt update
    RUN apt -y --force-yes install iptables iproute2 less iputils-ping netcat-openbsd
EOF
    if ! [[ "${COMMIT^^*}" =~ HEAD ]]; then
        # Old releases that cannot be compiled by new versions of go due to problems with modules
        git checkout $COMMIT
        docker run -it --rm -v $PWD/../../:/cwd  golang:1.12.17 bash -xc '
            mkdir -vp /go/src/github.com/coreos;
            ln -s /cwd /go/src/github.com/coreos/etcd;
            cd $_;
            bash -x ./build;
            rm -r gopath;
            chmod -vR 777 bin
        '
    else
        ./build.sh
    fi
    docker run -it --name issue-8129 --privileged --rm -v $PWD:/cwd issue-8129 /cwd/issue-8129.sh
    exit 0
fi

echo 1 |tee /proc/sys/net/ipv4/ip_forward
add_iface() {
    ip netns add e$1.ns
    ip netns exec e$1.ns ip link set up lo

    ip link add e$1.l type veth peer name e$1.r
    ip link set e$1.r netns e$1.ns

    ip netns exec e$1.ns ip link set up e$1.r
    ip netns exec e$1.ns ip addr add dev e$1.r 192.168.$1.1/24
    ip netns exec e$1.ns ip route add default via 192.168.$1.2

    ip link set up dev e$1.l
    ip addr add dev e$1.l 192.168.$1.2/24
}

instance() {
    add_iface $1

    rm -vrf "e$1"
    name="e$1"
    mkdir -vp $name

    until ip netns exec e$1.ns /cwd/bin/etcd --name $name \
          --data-dir $name \
          --listen-client-urls http://192.168.$1.1:2379 \
          --advertise-client-urls http://192.168.$1.1:2379 \
          --listen-peer-urls http://192.168.$1.1:2380 \
          --initial-advertise-peer-urls http://192.168.$1.1:2380 \
          --initial-cluster e1=http://192.168.1.1:2380,e2=http://192.168.2.1:2380,e3=http://192.168.3.1:2380 \
          --initial-cluster-token tkn \
          --initial-cluster-state new &>>$name/$name.log; do
        sleep 1
    done
}

check() {
    local ver
    ver=$(/cwd/bin/etcd --version|grep -Po 'etcd Version:\s\K.*')
    if [[ "$ver" =~ ^2[.] ]];then
        /cwd/bin/etcdctl \
          --endpoint http://192.168.1.1:2379,http://192.168.2.1:2379,http://192.168.3.1:2379 \
          -o extended cluster-health
    else
        cluster=""
        if [[ "$ver" =~ ^3[.]3[.] ]]; then 
            cluster="--cluster=true "
        fi
        ETCDCTL_API=3 /cwd/bin/etcdctl \
          --endpoints 192.168.1.1:2379,192.168.2.1:2379,192.168.3.1:2379 \
          $cluster endpoint status -w table
    fi
}

DIR="/cwd/tmp-issue-8129"
mkdir -vp $DIR
pushd $DIR

/cwd/bin/etcd --version

instance 1 &
instance 2 &
instance 3 &

until check; do
    sleep 0.5 # wait for cluster
done
ps axf|grep '\<[e]tcd '

read -p "add network split? (Y/y):"
iptables -I FORWARD -p tcp -s 192.168.1.1 -d 192.168.3.1 -j REJECT
iptables -I FORWARD -p tcp -s 192.168.3.1 -d 192.168.1.1 -j REJECT

trap 'set -x; pkill -9 -x etcd' TERM EXIT
set +xe
while true; do
    echo ">>>>>>>>>>>>>>>> iptables <<<<<<<<<<<<<<<<<<"
    iptables-save -c|grep FORWARD
    echo "................. check ...................."
    check
    echo "+++++++++++++++ procs ++++++++++++++++++++++"
    ps axf|grep '\<[e]tcd '|cut -c-80
    echo "################# LOGS ###################"
    tail -n5 e*/e*.log
    echo
    echo '_________________ [END] _________________'
    sleep 5
done
