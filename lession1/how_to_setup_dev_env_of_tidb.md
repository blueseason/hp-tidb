# How to setup develpoment enviroment of Tidb

## TiDB 背景知识
几篇关于TiDB设计的文章
-   [How we build TiDB](https://pingcap.com/blog-cn/how-do-we-build-tidb/)
-   [三篇文章了解 TiDB 技术内幕 - 说存储](https://pingcap.com/blog-cn/tidb-internal-1/)
-   [三篇文章了解 TiDB 技术内幕 - 说计算](https://pingcap.com/blog-cn/tidb-internal-2/)
-   [三篇文章了解 TiDB 技术内幕 - 谈调度](https://pingcap.com/blog-cn/tidb-internal-3/)


## Build Prerequiste

主要组件 TiKV，TiDB，PD，编译需要安装 go，rust。如需要编译docker，还需要docker环境。

下面命令在ubuntu 18.04LTS 下完成，其他环境类似。


### Install Go

目前的go版本为1.15,下载相应的tar包，解压缩到安装的目录

```
tar -C your_install_path -xzf go1.15.linux-amd64.tar.gz
```

在shell中设置GOROOT，GOPATH， PATH等环境变量
```
export GOROOT=your_go_install_path
export GOPATH=your_go_workspace
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

```


### Install Rust
使用rustup安装 比较简单
```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Build TiKV, TiDB, PD
三个子项目编译比较简单，用了Make进行管理，git clone 项目代码，运行 make 即可，其他的target 查看Makefile即可

TiKV 依赖cmake,需要安装
```
sudo apt install cmake
```

### Build error fix

#### git clone 项目 或者 go 依赖包 很慢或者无法连接
需要用代理
```
export ALL_PROXY=your_http_proxy (or socks5 proxy)
```
#### 编译TiKV 错误 `failed to resolve patches for https://github.com/rust-lang/crates.io-index`
参考 https://doc.rust-lang.org/cargo/reference/config.html#netgit-fetch-with-cli 
可以在 /projects/.cargo/config.toml文件加上设置
```
[net]
git-fetch-with-cli = true   # use the `git` executable for git operations

```
#### 编译TiDB 错误 `https://proxy.golang.org/github.com/%21jeffail/gabs/v2/@v/v2.5.1.mod": dial tcp 34.64.4.113:443: i/o timeout`
```
go env -w GOPROXY=https://goproxy.cn,direct
```

## Deploy local test cluster

使用TiUP 部署本地测试环境

### Install TiUP
```
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
```

### deploy
启动本地集群，用binpath指定本地代码路径
```
tiup playground  --db 1  --db.binpath ~/pingcap/tidb/bin/tidb-server --kv 3 --kv.binpath ~/pingcap/tikv/target/release/tikv-server --pd 1 --pd.binpath ~/pingcap/pd/bin/pd-server --tiflash 0
```

## 添加调试信息
从前面的总体架构设计中可知 事务处理是在tidb中完成，最终写入tikv存储的region，可在tidb模块中添加
1. tiup 集群dashboard 可以监控日志信息，
2. 通过 tiup client中运行 tranaction sql 语句进行调试追踪，大致经过了 session->excutor->2pc->tikv api层
3. 可以在2pc.go 726行， twoPhasecommitter 的 execute 函数中添加 
```
	logutil.Logger(ctx).Info("hello transaction")
```
4. 重新编译tidb, 部署，观察测试结果
