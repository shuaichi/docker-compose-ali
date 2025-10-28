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
使用这个数据库，执行 sql 脚本：https://github.com/shuaichi/FortuneBoot-Server/blob/master/sql/fortune-all.sql

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
# 部署教程

群晖:https://www.fortuneboot.com/archives/qun-hui-bu-shu-wen-dang    

绿联:https://www.fortuneboot.com/archives/lu-lian-ugos-probu-shu-hao-ji

1panel:https://www.fortuneboot.com/archives/1panelbu-shu-hao-ji    

宝塔:https://www.fortuneboot.com/archives/bao-ta-bu-shu-hao-ji

命令行:https://www.fortuneboot.com/archives/dockerming-ling-xing-bu-shu-hao-ji

# 9快记账数据迁移至好记记账
1、好记数据库依赖mysql8.0及以上版本，如果你是使用的5.7请先升级mysql版本后再升级。
2、在9快数据库实例上创建一个新的schema，并执行上面创建数据库表的sql。
3、下载数据迁移脚本 https://github.com/shuaichi/docker-compose-ali/blob/main/9%E5%BF%AB%E6%95%B0%E6%8D%AE%E8%BF%81%E7%A7%BB%E8%87%B3%E5%A5%BD%E8%AE%B0.sql
4、修改如下数据库脚本至自己的。
```sql
  -- 使用新的数据库
  use fortune_boot;
  -- 新的数据库
  SET @new_schema = 'fortune_boot';
  -- 旧的数据库
  SET @old_schema = 'moneynote';
  -- 迁移到好记的用户 id
  SET @new_user_id = 1;
  -- 要迁移的用户id
  SET @old_user_id = 1;
```
5、执行数据库脚本。
