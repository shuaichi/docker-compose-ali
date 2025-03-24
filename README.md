# docker-compose-ali

# 一键启动命令
docker-compose-all-in-one.yaml同级目录下执行以下命令
```bash
docker-compose docker-compose-all-in-one.yaml up -d
```

# 基于已有 mysql/mariadb 和 redis 启动
下载 docker-compose-only-app.yaml

修改其中的 
  数据库地址、端口、名称、账号、密码；
  redis地址、端口、密码（如果有的话）
  
修改完成后，在docker-compose-only-app.yaml同级目录下执行以下命令
```bash
docker-compose docker-compose-only-app.yaml up -d
```
