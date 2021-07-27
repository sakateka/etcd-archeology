## Воспроизведение проблемы из #7798

1. Поднять кластер из 3х нод (допустим s1 s2 s3)
2. Удалить dns запись для одной из нод (допустим s3)
3. Дождаться, когда dns кэш перестанет резолвить удалённую запись.
4. Выключить одну из нод (допустим s2)
5. Удалить данные для этой ноды (s2)
6. Попробовать запустить ноду с `--initial-cluster-state existing`

Для решение данной проблемы нужно добавить short path для сравнения URL-ов из URLStringsEqual
pkg/netutil/netutil.go#199

```go
    urlsA := make([]url.URL, 0)
    for _, str := range a {
        u, err := url.Parse(str)
        if err != nil {
            return false, fmt.Errorf("failed to parse %q", str)
        }
        urlsA = append(urlsA, *u)
    }
    urlsB := make([]url.URL, 0)
    for _, str := range b {
        u, err := url.Parse(str)
        if err != nil {
            return false, fmt.Errorf("failed to parse %q", str)
        }
        urlsB = append(urlsB, *u)
    }


    // TODO: Compare URLs without resolving and continue with resolving
    // only if comparison fails.
```

Как запускать.

Нужно склонировать этот репозиторий в корень github.com/etcd-io/etcd
```
cd github.com/etcd-io/etcd
git clone https://github.com/sakateka/etcd-archeology
cd etcd-archeology/issue-7798/
./issue-7798.sh [patched]
```
