#!/bin/bash
set -xue
HOSTS=${HOSTS:-/etc/hosts}

if ! grep docker /proc/1/cgroup; then
    docker run -it --rm -v $PWD/v3.5.0:/v3.5.0 -v $PWD:/cwd -v $PWD/../../bin/:/patched ubuntu /cwd/issue-7798.sh $1
    exit 0
fi

if ! test -w $HOSTS; then
    echo "It is assumed that you have write rights to the $HOSTS"
    exit 1
fi

trap 'pkill -9 -x etcd' TERM EXIT ERR

TYPE="${1:-v3.5.0}"

instance() {
    rm -vrf "e$1"
    name="e$1"

    declare -A ports=(
        [e1]=2379
        [e2]=22379
        [e3]=32379
    )

    exec /$TYPE/etcd --name $name \
      --data-dir $name \
      --listen-client-urls http://127.0.0.1"$1":${ports[$name]} \
      --advertise-client-urls http://${name}.lan:${ports[$name]} \
      --listen-peer-urls http://127.0.0.1"$1":$((${ports[$name]}+1)) \
      --initial-advertise-peer-urls http://${name}.lan:$((${ports[$name]}+1)) \
      --initial-cluster e1=http://e1.lan:2380,e2=http://e2.lan:22380,e3=http://e3.lan:32380 \
      --initial-cluster-token tkn \
      --initial-cluster-state ${2:-new} &> $name.log
}

check() {
    ETCDCTL_API=3 /$TYPE/etcdctl \
      --endpoints e1.lan:2379,e2.lan:22379,e3.lan:32379 \
      endpoint health
}

ls -lh /$TYPE/
DIR="etcd-$TYPE"
mkdir -vp $DIR
pushd $DIR

echo "Fix $HOSTS"
echo "127.0.0.11 e1.lan
127.0.0.12 e2.lan
127.0.0.13 e3.lan" > $HOSTS
grep -P 'e\d.lan' $HOSTS

instance 1 &
E1PID=$!

instance 2 &
E2PID=$!

instance 3 &
E3PID=$!

until check; do
    sleep 5 # wait for cluster
done

kill -9 $E2PID $E3PID

echo "127.0.0.11 e1.lan
127.0.0.12 e2.lan" > $HOSTS
cat $HOSTS
sleep 5

instance 2 existing &
E2PID=$!
until check; do
    sleep 5
    ps axf|grep '\<[e]tcd '
    tail -n1 e*.log
done
