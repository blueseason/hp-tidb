# TiDB Base Testing

## Base Testing 背景知识
1. [用 TiUP 部署 TiDB 集群]( https://docs.pingcap.com/zh/tidb/stable/production-deployment-using-tiup)
2. [TiKV 线程池优化](https://github.com/pingcap-incubator/tidb-in-action/blob/master/session4/chapter8/threadpool-optimize.md)
3. [PD Dashboard 说明](https://docs.pingcap.com/zh/tidb/stable/dashboard-intro)
4. [TPCC 背景知识](https://github.com/pingcap-incubator/tidb-in-action/blob/master/session4/chapter3/tpc-c.md)
5. [ycsb,sysbench](https://github.com/pingcap-incubator/tidb-in-action/blob/master/session4/chapter3/sysbench.md)

## 搭建测试环境

在单机上可以利用vitualbox, vagrant自动部署多台虚拟机供测试环境使用，virtualbox和vagrant安装比较简单，这里不再赘述。

本机的配置为intel i7 8750H 6 core, 16gb, wd blue 500gb ssd

拓扑结构如以下
- TiDB 1台，每台配置 1 core 2GB
- TiKV 3台，每台配置 1 core 2GB
- PD   1台，每台配置 1 core 2GB


vagrant file 如下
```
ENV["LC_ALL"] = "en_US.UTF-8"

Vagrant.configure("2") do |config|
  config.vm.box = "season/bionic64-base"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
  end
  config.disksize.size = '20GB'

  config.ssh.username = "devops"
  #config.ssh.password = "vagrant"
  #config.ssh.keys_only = "false"
  #config.ssh.private_key_path = "/home/season/.ssh/id_rsa"

  # tidb
  config.vm.define "tidb" do |guest|
    guest.vm.hostname = "tidb"
    guest.vm.network "private_network", ip: "10.0.100.100"
  end

  config.vm.define "pd" do |guest|
    guest.vm.hostname = "pd"
    guest.vm.network "private_network", ip: "10.0.100.101"
  end

  # tikv node 1,2,3
  (3..5).each do |i|

    config.vm.define "tikv#{i-2}" do |node|
      node.vm.hostname = "tikv#{i-2}"
      node.vm.network "private_network", ip: "10.0..100.#{i+100}"
    end
  end

end
```

运行vagrant up 启动虚拟机，vagrant status 查看状态
```
Current machine states:

tidb                      running (virtualbox)
pd                        running (virtualbox)
tikv1                     running (virtualbox)
tikv2                     running (virtualbox)
tikv3                     running (virtualbox)


```


tidb cluster 配置文件如下
```
# # Global variables are applied to all deployments and used as the default value of
# # the deployments if a specific deployment value is missing.
global:
  user: "tidb"
  ssh_port: 22
  deploy_dir: "/tidb-deploy"
  data_dir: "/tidb-data"

# # Monitored variables are applied to all the machines.
monitored:
  node_exporter_port: 9100
  blackbox_exporter_port: 9115
  # deploy_dir: "/tidb-deploy/monitored-9100"
  # data_dir: "/tidb-data/monitored-9100"
  # log_dir: "/tidb-deploy/monitored-9100/log"

# # Server configs are used to specify the runtime configuration of TiDB components.
# # All configuration items can be found in TiDB docs:
# # - TiDB: https://pingcap.com/docs/stable/reference/configuration/tidb-server/configuration-file/
# # - TiKV: https://pingcap.com/docs/stable/reference/configuration/tikv-server/configuration-file/
# # - PD: https://pingcap.com/docs/stable/reference/configuration/pd-server/configuration-file/
# # All configuration items use points to represent the hierarchy, e.g:
# #   readpool.storage.use-unified-pool
# #
# # You can overwrite this configuration via the instance-level `config` field.

server_configs:
  tidb:
    log.slow-threshold: 300
    binlog.enable: false
    binlog.ignore-error: false
  tikv:
    # server.grpc-concurrency: 4
    # raftstore.apply-pool-size: 2
    # raftstore.store-pool-size: 2
    # rocksdb.max-sub-compactions: 1
    # storage.block-cache.capacity: "16GB"
    # readpool.unified.max-thread-count: 12
    readpool.storage.use-unified-pool: false
    readpool.coprocessor.use-unified-pool: true
  pd:
    schedule.leader-schedule-limit: 4
    schedule.region-schedule-limit: 2048
    schedule.replica-schedule-limit: 64

pd_servers:
  - host: 10.0.100.101
    # ssh_port: 22
    # name: "pd-1"
    # client_port: 2379
    # peer_port: 2380
    # deploy_dir: "/tidb-deploy/pd-2379"
    # data_dir: "/tidb-data/pd-2379"
    # log_dir: "/tidb-deploy/pd-2379/log"
    # numa_node: "0,1"
    # # The following configs are used to overwrite the `server_configs.pd` values.
    # config:
    #   schedule.max-merge-region-size: 20
    #   schedule.max-merge-region-keys: 200000


tidb_servers:
  - host: 10.0.100.100
    # ssh_port: 22
    # port: 4000
    # status_port: 10080
    # deploy_dir: "/tidb-deploy/tidb-4000"
    # log_dir: "/tidb-deploy/tidb-4000/log"
    # numa_node: "0,1"
    # # The following configs are used to overwrite the `server_configs.tidb` values.
    # config:
    #   log.slow-query-file: tidb-slow-overwrited.log


tikv_servers:
  - host: 10.0.100.103
    # ssh_port: 22
    # port: 20160
    # status_port: 20180
    # deploy_dir: "/tidb-deploy/tikv-20160"
    # data_dir: "/tidb-data/tikv-20160"
    # log_dir: "/tidb-deploy/tikv-20160/log"
    # numa_node: "0,1"
    # # The following configs are used to overwrite the `server_configs.tikv` values.
    # config:
    #   server.grpc-concurrency: 4
    #   server.labels: { zone: "zone1", dc: "dc1", host: "host1" }
  - host: 10.0.100.104
  - host: 10.0.100.105

monitoring_servers:
  - host: 10.0.100.101
    # ssh_port: 22
    # port: 9090
    # deploy_dir: "/tidb-deploy/prometheus-8249"
    # data_dir: "/tidb-data/prometheus-8249"
    # log_dir: "/tidb-deploy/prometheus-8249/log"

grafana_servers:
  - host: 10.0.100.101
    # port: 3000
    # deploy_dir: /tidb-deploy/grafana-3000

alertmanager_servers:
  - host: 10.0.100.101
    # ssh_port: 22
    # web_port: 9093
    # cluster_port: 9094
    # deploy_dir: "/tidb-deploy/alertmanager-9093"
    # data_dir: "/tidb-data/alertmanager-9093"
    # log_dir: "/tidb-deploy/alertmanager-9093/log"
```

TiUP 部署集群
```
 tiup cluster deploy tidb-benchmark nightly ./complex-mini.yaml --user devops

```

集群节点截图:
![tidb_cluster](https://github.com/blueseason/hp-tidb/blob/master/lession2/arch.png "tidb_cluster")


启动TiDB集群, 观察一下机群状态
```
tiup cluster start tidb-benchmark

tiup cluster display tidb-benchmark

```

## Sysbench 测试

### ubuntu 安装 和初始化

```
curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash
sudo apt -y install sysbench
```
初始化和导入数据
```
mysql -h 10.0.100.100 -P 4000 -u root

show databases;

create database sbtest;

set global tidb_disable_txn_auto_retry = off;

#导入前设置事务模型为乐观
set global tidb_txn_mode="optimistic";
#导入之后恢复
set global tidb_txn_mode="pessimistic";

```

### 测试过程
受限于本地机器性能，测试在数据表大小为1W，10W的规模下依次运行oltp_point_select，oltp_update_index，oltp_read_only
各两分钟

![1W_QPS](https://github.com/blueseason/hp-tidb/blob/master/lession2/qps1.png "1W数据 三项测试 QPS")

其中oltp_point_selelct QPS 最高，中间低谷的为 oltp_update_index测试，最后为 oltp_read_only.

跑oltp_point_select和 oltp_read_only时节点监控状态类似，如下图

![1W_QPS_node_load](https://github.com/blueseason/hp-tidb/blob/master/lession2/cpu1.png "1W数据 节点负载")

跑oltp_update_index时节点负载状态如下

![1W_QPS_node_load1](https://github.com/blueseason/hp-tidb/blob/master/lession2/cpu2.png "1W数据 oltp_update_index 节点负载")

10w数据规模下，在导入数据阶段即出现下面的错误,一台tikv机器异常无法连接，测试无法进行下去

```
FATAL: mysql_drv_query() returned error 8027 (Information schema is out of date: schema failed to update in 1 lease, please make sure TiDB can connect to TiKV)
```
从节点负载监控可以看到那台tikv节点2G内存已经用满，由于在本次的测试环境几台虚拟机共用一块硬盘这比较明显的瓶颈点，硬盘读写慢,写入大量数据耗尽内存，使得tikv无法继续响应tidb的rpc请求.


## go-ycsb 测试
go-ycsb workload 有a-f六个测试，基本命令如下，先导入再运行

```
./bin/go-ycsb load mysql -P workloads/workloada -p recordcount=10000 -p mysql.host=10.0.100.100 -p mysql.port=4000 --threads 32

./bin/go-ycsb run mysql -P workloads/workloada -p recordcount=10000 -p mysql.host=10.0.100.100 -p mysql.port=4000 --threads 32
```
本次测试了数据规模在1w,10w,100w下的各workload

QPS图如下,前面的一段是1W数据下运行workload的负载，中间一段是导入100w数据的负载，QPS最高的一段是导入10W数据时
![ycsb_QPS](https://github.com/blueseason/hp-tidb/blob/master/lession2/ycsb2_qps.png "ycsb QPS")

tidb的节点负载
![ycsb_node_load](https://github.com/blueseason/hp-tidb/blob/master/lession2/ycsb_cpu.png "ycsb node load")


## go-tpc 测试
gp-tpc是针对电商平台场景的测试，数据导入阶段需要大量的硬盘写入，warehouses 1000时大约64G读写，3个节点大约192G
需要提前计算好个虚拟机所需硬盘大小，在vagrant中如下配置硬盘大小

```
  config.disksize.size = '40GB'
```
考虑机器硬盘只有500G,选择warehouse=8进行测试，并且放弃了数据读写要求更高的tpc-h测试

测试命令如下

```
./bin/go-tpc tpcc -H 10.0.100.100 -P 4000 -D tpcc --warehouses 8 prepare -T 8
```

```
./bin/go-tpc tpcc -H 10.0.100.100 -P 4000 -D tpcc --warehouses 8 run --time 2m --threads 4
```

QPS图如下

![tpcc_QPS](https://github.com/blueseason/hp-tidb/blob/master/lession2/tpcc_qps.png "tpcc QPS")

节点负载图如下

![tpcc_load](https://github.com/blueseason/hp-tidb/blob/master/lession2/tpcc_cpu.png "tpcc load")

最后测试 tpmC: 338.9


## 结果分析
受限于单机的原因，本测试环境有较大的局限性，结果本身没有价值，但是测试过程中的一些数据可以做略作分析
1. 由于资源有限(CPU,Memory不够)，测试端和被测试测端未全完全隔离，存在竞争，影响结果
2. 硬盘只有一块，在update或者写操作时，几个tikv存在竞争关系，比如在sysbench update测试QPS低很多，以及在导入10W数据集时一台tikv宕机不能提供服务，都是和此相关.正常的情况下，如果有几块硬盘，将tikv数据分区挂载到独立硬盘上，会有比较好的表现
3. 受限于内存(2G),只能测试较小的数据集规模(1W-10W). 对于读操作测试，单台tidb已经可以到12kQPS。但是写相关的操作由于硬盘瓶颈会爆内存，QPS也很低，如果内存多些，tidb和tikv的内存可以分配(4g-8g),可以测试更大规模的数据集，QPS也会有较大改善
4. 由于主机CPU只有6核12线程，在当前配置下，将server.grpc-concurrency设成2，rocksdb.max-background-jobs，raftdb.max-background-jobs 改为 2 可能有更好的QPS.
5. tpc-c和tpc-h测试对于硬盘写入要求高，特别时基于OLAP的tpc-h测试，单机单硬盘的环境就不太适合了，测试中遇到多次硬盘写满节点宕机的情况


