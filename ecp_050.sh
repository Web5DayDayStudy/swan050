#!/bin/bash

# 确保脚本在任何命令失败时退出
set -e

pids=$(ps -ef | grep computing | grep -v grep | awk '{print $2}')

if [ -n "$pids" ]; then
  echo "Killing processes: $pids"
  echo $pids | xargs kill
else
  echo "No processes found for 'computing'."
fi

# 函数：生成10位随机小写字母字符串
generate_random_string() {
  tr -dc 'a-z' < /dev/urandom | head -c 10
}

# 交互式输入参数
read -p "请输入IP: " IP
read -p "请输入钱包地址: " ADDRESS
read -p "请输入私钥去掉0x: " PRIVATE_KEY
read -p "请输入质押金额(每次消耗0.0005): " COLLATERAL_AMOUNT

# 生成10位随机小写字母字符串
NODE_NAME=$(generate_random_string)
echo "生成的节点名称是：$NODE_NAME"

# 删除旧的运行环境
echo ">>>删除.swan"
rm -rf .swan/

# 根目录
cd ~

# 备份私钥
if [ -f "private.key" ]; then
  echo ">>>正在备份私钥"
  cp private.key private_backup.key
else
  echo ">>>私钥文件不存在，跳过备份"
fi


# 将私钥写入文件
echo ">>>写入私钥到 private.key"
echo $PRIVATE_KEY > private.key

# 停止并移除 Docker 容器
echo ">>>停止并移除容器 ubi-redis 和 resource-exporter"
docker stop ubi-redis resource-exporter || true
docker rm ubi-redis resource-exporter || true

# 删除旧的 computing-provider
echo ">>>删除旧的 computing-provider"
rm -rf computing-provider

# 下载新的 computing-provider
echo ">>>下载新的 computing-provider"
wget https://github.com/swanchain/go-computing-provider/releases/download/v0.5.1/computing-provider
# 检查下载是否成功
if [ ! -f "computing-provider" ]; then
  echo "Error: 下载 computing-provider 失败"
  exit 1
fi

# 添加执行权限
echo ">>>添加执行权限"
chmod +x computing-provider

# 初始化 computing-provider
echo ">>>初始化 computing-provider"
./computing-provider init --multi-address=/ip4/$IP/tcp/9085 --node-name=$NODE_NAME

# 导入钱包私钥
echo ">>>导入钱包私钥"
./computing-provider wallet import private.key

# 创建账户
echo ">>>创建账户"
./computing-provider account create --ownerAddress $ADDRESS --workerAddress $ADDRESS --beneficiaryAddress $ADDRESS --task-types 1,2,4
sleep 5

# 增加抵押
echo ">>>增加质押"
./computing-provider collateral add --ecp --from=$ADDRESS $COLLATERAL_AMOUNT
sleep 5

# 启动 ubi daemon
echo ">>>启动 ubi daemon"
nohup ./computing-provider ubi daemon >> cp.log 2>&1 &
