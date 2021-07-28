## How to run
```
cd github.com/etcd-io/etcd
git checkout v3.5.0
git clone https://github.com/sakateka/etcd-archeology
git apply etcd-archeology/issue-8181/issue-8181-insight.patch
cd etcd-archeology/issue-8181/
./issue-8181.sh
```

Eventually to stdout will be displayed like this

```
2021-07-27T16:47:34.998Z	INFO	v3/lease.go:515	lease with TTL=0	{"TTL": 0, "lease-keepalive-response": "header:<cluster_id:14591485659949351572 member_id:2107781708884220754 revision:1 raft_term:3 > ID:6494607278208502104 "}
2021-07-27T16:47:34.998Z	INFO	concurrency/session.go:73	do not alive KeepAlive for lease	{"id": 6494607278208502104}
2021-07-27T16:47:34.998Z	INFO	issue-8181/client.go:69	Canceled by etcd, ctxErr=<nil>

```

cluster leader
```
$ rg 'elected leader' data/e*.log
data/e3.log
221:{"level":"info","ts":"2021-07-27T16:47:34.591Z","logger":"raft","caller":"etcdserver/zap_raft.go:77","msg":"raft.node: 9377a111dda6da21 elected leader 1d40584bf61c1b52 at term 3"}

data/e2.log
231:{"level":"info","ts":"2021-07-27T16:47:34.591Z","logger":"raft","caller":"etcdserver/zap_raft.go:77","msg":"raft.node: 1d40584bf61c1b52 elected leader 1d40584bf61c1b52 at term 3"}

data/e1.log
212:{"level":"info","ts":"2021-07-27T16:47:34.591Z","logger":"raft","caller":"etcdserver/zap_raft.go:77","msg":"raft.node: ed398ac0e0cb95a elected leader 1d40584bf61c1b52 at term 3"}

```

## failed lease logs

```
rg 6494607278208502104 data/e*.log
```

## follower data/e3.log
```
362:{"level":"info","ts":"2021-07-27T16:47:34.896Z","caller":"lease/lessor.go:292","msg":"Add lease: &{6494607278208502104 120 0 {{0 0} 0 0 0 0} {0 0 <nil>} {{0 0} 0 0 0 0} map[] 0xc00041cde0}"}
```

## leader data/e2.log
```
378:{"level":"info","ts":"2021-07-27T16:47:34.909Z","caller":"etcdserver/v3_server.go:285","msg":"lease renew result","leader":true,"id":6494607278208502104,"ttl":-1,"error":"lease not found"}
386:{"level":"info","ts":"2021-07-27T16:47:34.921Z","caller":"lease/lessor.go:292","msg":"Add lease: &{6494607278208502104 120 0 {{0 0} 0 0 0 0} {13850869203061893234 120862812617 0x1a93860} {{0 0} 0 0 0 0} map[] 0xc0000c54a0}"}
```

## follower data/e1.log
```
349:{"level":"info","ts":"2021-07-27T16:47:34.888Z","caller":"lease/lessor.go:292","msg":"Add lease: &{6494607278208502104 120 0 {{0 0} 0 0 0 0} {0 0 <nil>} {{0 0} 0 0 0 0} map[] 0xc0037fb3e0}"}
```
