## Проблема #issue-8129
Заключается в утере возможности переживать разделение сети между некоторыми нодами кластера.
Это случилось после внедрения механизма Lease при включенном QuorumCheck и дальше PreVote.
Простой пример, допустим в обычной ситуации все ноды видят друг друга, но в какой-то момент
происходит разделение сети между нодами B и C.
```
     A
    / \
   /   \
  B -x- C
```
После разрыва связи между B и C связанность по прежнему есть между A и B, и между A и C.
Если в момент разрыва leader etcd кластера бала нода A, то всё продолжит работать.
Ноды B и C продолжать быть follower-ами и обслуживать запросы.

Но если во время разрыва leader была нода B или C, то в кластер версии 3.0.0 и более
сломается та нода, которая перестала видеть leader-а.


В кластере до версии 3.0.0-beta1 было другое поведение, после разрыва связи начинались
перевыборы, инициатором которых бала нода, которая не видит leader-а.
Соседний follower реагировал на эти перевыборы и в итоге текущий мастер откатывался до
follower-а. В результате перевыборов нода А (которая видит всех) становилась мастером.


## Воспроизведение с помощью скрипта issue-8129.sh
Запускать следующим образом

```
cd github.com/etcd-io/etcd
git clone https://github.com/sakateka/etcd-archeology
cd etcd-archeology/issue-8129/
./issue-8129.sh [git commit to build from]
```

Если не указать коммит, то будет подставлен коммит со "старым" поведением
