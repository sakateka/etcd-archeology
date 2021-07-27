#!/bin/bash
set -uxme

if ! grep docker /proc/1/cgroup; then
    pushd ../..
    ./build.sh
    popd
    rm -v client || true
    go build client.go
    docker run -it --name issue-8181 --rm -v $PWD/../../:/cwd ubuntu:latest /cwd/etcd-archeology/issue-8181/issue-8181.sh
    exit 0
fi

trap 'pkill -9 -x etcd' TERM EXIT ERR

instance() {
    name="e$1"
    until /cwd/bin/etcd --name $name \
      --data-dir /cwd/issue-8181/data/$name \
      --listen-client-urls http://127.0.0.$1:2379 \
      --advertise-client-urls http://127.0.0.$1:2379 \
      --listen-peer-urls http://127.0.0.$1:2380\
      --initial-advertise-peer-urls http://127.0.0.$1:2380 \
      --initial-cluster e1=http://127.0.0.1:2380,e2=http://127.0.0.2:2380,e3=http://127.0.0.3:2380 \
      --initial-cluster-token tkn \
      --initial-cluster-state new &> /cwd/etcd-archeology/issue-8181/data/$name.log; do
      sleep 0.1
    done
}

ENDPOINTS=http://127.0.0.1:2379,http://127.0.0.2:2379,http://127.0.0.3:2379
check() {
    ETCDCTL_API=3 /cwd/bin/etcdctl --endpoints "$ENDPOINTS" endpoint health
}

rm -vrf /cwd/etcd-archeology/issue-8181/data
mkdir -vp /cwd/etcd-archeology/issue-8181/data

instance 1 &
instance 2 &
instance 3 &

until check; do
    sleep 1 # wait for cluster
done

/cwd/etcd-archeology/issue-8181/client "$ENDPOINTS" || true
/cwd/bin/etcdctl lease list|sed 1d|xargs -P10 -n1 /cwd/bin/etcdctl lease timetolive
