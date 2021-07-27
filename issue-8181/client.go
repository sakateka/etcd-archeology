package main

import (
	"context"
	"fmt"
	"math/rand"
	"os"
	"strings"
	"time"

	clientv3 "go.etcd.io/etcd/client/v3"
	"go.etcd.io/etcd/client/v3/concurrency"
	"go.uber.org/zap"
)

var zl *zap.Logger
var log *zap.SugaredLogger

func init() {
	var zc = zap.NewDevelopmentConfig()
	zc.Level = zap.NewAtomicLevelAt(zap.InfoLevel)
	zl, _ = zc.Build()
	log = zl.Sugar()
}

func doSomething(ev interface{}) error {
	log.Infof("Event: %v", ev)
	return nil
}

func myWatch(ctx context.Context, client *clientv3.Client) error {
	session, err := concurrency.NewSession(
		client,
		concurrency.WithTTL(120),
		concurrency.WithContext(ctx),
	)
	if err != nil {
		return fmt.Errorf("failed to establish a session to the etcd: %w", err)
	}

	watchCtx, watchCancel := context.WithCancel(ctx)
	defer watchCancel()
	watchRet := make(chan error, 1)
	go func() {
		watchRet <- func() error { // wrap by a func to make sure watchRet gets item
			rch := client.Watch(watchCtx, "/yep", clientv3.WithPrefix())

			for wresp := range rch {
				err := wresp.Err()
				if err != nil {
					return err
				}
				for _, ev := range wresp.Events {
					err := doSomething(ev)
					if err != nil {
						return err
					}
				}
			}

			return nil
		}()
	}()

	os.Stdout.WriteString("|")

	select {
	case <-session.Done(): // closed by etcd
		log.Infof("\x1b[1;31mCanceled by etcd, ctxErr=%v\x1b[0;0m", ctx.Err())
		select {
		case err := <-watchRet:
			log.Infof("Watch err: %v", err)
		default:
		}
		select {
		case <-ctx.Done():
			log.Info("Ctx done")
		default:
		}
		_ = os.Stderr.Sync()
		panic("Connection to the etcd closed")
	case <-ctx.Done(): // user cancel
		os.Stdout.WriteString("\x1b[1;32m-\x1b[0;0m")
		return ctx.Err()
	case err := <-watchRet:
		log.Info("\x1b[1;36mError in watcher\x1b[0;0m")
		return err
	}
}

func newClient() {
	cli, err := clientv3.New(clientv3.Config{
		Logger:      zl,
		Endpoints:   strings.Split(os.Args[1], ","),
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		log.Fatalf("clientv3.New err: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(15+rand.Intn(10))*time.Second)
	defer cancel()
	_ = myWatch(ctx, cli)
}

func main() {
	rand.Seed(time.Now().UnixNano())

	n := 500
	clients := make(chan struct{}, n)
	for {
		clients <- struct{}{}
		go func() {
			newClient()
			<-clients
		}()
	}
}
