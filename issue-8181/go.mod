module tmp

go 1.16

require (
	go.etcd.io/etcd/client/v3 v3.5.0
	go.uber.org/zap v1.17.0
	golang.org/x/sys v0.0.0-20210630005230-0f9fa26af87c // indirect
)

replace (
	go.etcd.io/etcd/api/v3 => ../../api
	go.etcd.io/etcd/client/pkg/v3 => ../../client/pkg
	go.etcd.io/etcd/client/v2 => ../../client/v2
	go.etcd.io/etcd/client/v3 => ../../client/v3
	go.etcd.io/etcd/etcdutl/v3 => ../../etcdutl
	go.etcd.io/etcd/pkg/v3 => ../../pkg
	go.etcd.io/etcd/raft/v3 => ../../raft
	go.etcd.io/etcd/server/v3 => ../../server
)
