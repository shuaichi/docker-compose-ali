# docker-compose-ali

# 一键启动命令
docker-compose-all-in-one.yaml同级目录下执行以下命令
```bash
docker-compose -f docker-compose-all-in-one.yaml up -d
```

# 基于已有 mysql/mariadb 和 redis 启动
创建数据库，执行创建数据库命令：
```sql
CREATE DATABASE IF NOT EXISTS fortune_boot CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```
使用这个数据库，执行 sql 脚本：https://github.com/shuaichi/FortuneBoot-Server/blob/master/sql/fortune-all-20250306.sql

下载 docker-compose-only-app.yaml并修改：
```
数据库地址、端口、名称、账号、密码
redis地址、端口、密码（如果有的话）
建议修改：RSA公钥、私钥
```
修改完成后，在docker-compose-only-app.yaml同级目录下执行以下命令
```bash
docker-compose -f docker-compose-only-app.yaml up -d
```
