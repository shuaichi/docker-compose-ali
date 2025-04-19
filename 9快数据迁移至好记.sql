-- 以下为环境变量，这里需要修改
-- ---------- begin ------------
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
-- ----------- end -------------
-- 以上为环境变量，请修改为自己的变量

-- 以下为迁移数据库脚本，不要动.
-- 迁移阶段（使用存储过程处理动态 schema）
DELIMITER $$

CREATE PROCEDURE migrate_data()
BEGIN
    -- ========== 第一阶段 设置各个表的最大ID ==========
    -- 获取新分组最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(group_id), 0) + 1 INTO @group_shift ',
        'FROM ', @new_schema, '.fortune_group'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新关系表最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(user_group_relation_id), 0) + 1 INTO @relation_shift ',
        'FROM ', @new_schema, '.fortune_user_group_relation'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新账户最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(account_id), 0) INTO @account_shift ',
        'FROM ', @new_schema, '.fortune_account'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新账本最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(book_id), 0) + 1 INTO @book_shift ',
        'FROM ', @new_schema, '.fortune_book'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新分类最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(category_id), 0) + 1 INTO @category_shift ',
        'FROM ', @new_schema, '.fortune_category'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新交易对象最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(payee_id), 0) + 1 INTO @payee_shift ',
        'FROM ', @new_schema, '.fortune_payee'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新标签最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(tag_id), 0) + 1 INTO @tag_shift ',
        'FROM ', @new_schema, '.fortune_tag'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新账单表最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(bill_id), 0) + 1 INTO @bill_shift ',
        'FROM ', @new_schema, '.fortune_bill'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新关系表最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(category_relation_id), 0) + 1 INTO @category_rel_shift ',
        'FROM ', @new_schema, '.fortune_category_relation'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新关系表最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(tag_relation_id), 0) + 1 INTO @tag_rel_shift ',
        'FROM ', @new_schema, '.fortune_tag_relation'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 获取新文件表最大ID
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(file_id), 0) + 1 INTO @file_shift ',
        'FROM ', @new_schema, '.fortune_file'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- ========== 第二阶段 迁移数据数据 ==========
    -- ---------- 迁移分组数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_group ',
        '(group_id, group_name, default_currency, enable, remark, default_book_id, creator_id, updater_id, create_time, update_time) ',
        'SELECT old.id + @group_shift, ',
               'old.name, ',
               'old.default_currency_code, ',
               'old.enable, ',
               'old.notes, ',
               'old.default_book_id + @book_shift, ',
                @new_user_id, ', ',  -- creator_id
                @new_user_id, ', ',  -- updater_id
                'NOW(), ',  -- create_time
                'NOW() ',  -- update_time
        'FROM ', @old_schema, '.t_user_group AS old ',
        'WHERE EXISTS (',
            'SELECT 1 FROM ', @old_schema, '.t_user_user_group_relation ',
            'WHERE group_id = old.id AND user_id = @old_user_id',
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- ---------- 迁移用户/分组关系数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_user_group_relation ',
        '(user_group_relation_id, role_type, group_id, user_id, default_group, ',
            'creator_id, updater_id, create_time, update_time) ',
        'SELECT old.id + @relation_shift, ',
               'old.role, ',
               'old.group_id + @group_shift, ',
               @new_user_id, ', ',
               'tuu.default_group_id, ',
               @new_user_id, ', ',  -- creator_id
               @new_user_id, ', ',  -- updater_id
               'NOW(), ',  -- create_time
               'NOW() ',  -- update_time
        'FROM ', @old_schema, '.t_user_user_group_relation AS old ',
        'INNER JOIN ',@old_schema, '.t_user_user AS tuu ',
        'ON old.user_id = tuu.id ',
        'WHERE user_id = @old_user_id'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置关系表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(user_group_relation_id), 0) + 1 INTO @next_rel_id ',
        'FROM ', @new_schema, '.fortune_user_group_relation'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_user_group_relation ',
        'AUTO_INCREMENT = ', @next_rel_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- ---------- 迁移账户数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_account ',
        '(account_id, card_no, account_name, balance, bill_day, can_expense, can_income, ',
        'can_transfer_out, can_transfer_in, credit_limit, currency_code, enable, ',
        'include, apr, initial_balance, account_type, group_id, sort, remark, ',
        'creator_id, updater_id, create_time, update_time, recycle_bin) ',
        'SELECT ',
        'old.id + @account_shift, ',  -- 应用账户ID偏移
        'old.no, '
        'old.name, ',
        'CAST(old.balance AS DECIMAL(20,4)), ',
        'CASE WHEN old.bill_day IS NOT NULL THEN ',
            'STR_TO_DATE(',
                'CONCAT(YEAR(NOW()), "-", LPAD(LEAST(old.bill_day, 12), 2, "0"), "-01"), ',  -- 限制月份<=12
                '"%Y-%m-%d"',
            ') ',
        'ELSE NULL END, ',  -- 修正此处
        'old.can_expense, ',
        'old.can_income, ',
        'old.can_transfer_from, ',
        'old.can_transfer_to, ',
        'old.credit_limit, ',
        'old.currency_code, ',
        'old.enable, ',
        'old.include, ',
        'old.apr, ',
        'CAST(old.initial_balance AS DECIMAL(20,4)), ',
        'CASE old.type ',
            'WHEN 100 THEN 1 ',  -- 类型映射示例
            'WHEN 200 THEN 2 ',
            'WHEN 300 THEN 3 '
            'ELSE 4 END, ',
        'old.group_id + @group_shift, ',  -- 应用分组偏移
        'old.ranking, ',
        'IFNULL(old.notes,''''), ',  -- 确保逗号
        @new_user_id, ', ',  -- creator_id
        @new_user_id, ', ',  -- updater_id
        'NOW(), ',  -- create_time
        'NOW(), ',  -- update_time
        'old.deleted ',
        'FROM ', @old_schema, '.t_user_account AS old ',
        'WHERE old.group_id IN (',
            'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
            'WHERE user_id = ',@old_user_id ,
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置账户表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(account_id), 0) + 1 INTO @next_account_id ',
        'FROM ', @new_schema, '.fortune_account'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_account ',
        'AUTO_INCREMENT = ', @next_account_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- ---------- 迁移账本数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_book ',
        '(book_id, group_id, book_name, default_currency, ',
        'default_expense_account_id, default_income_account_id, ',
        'default_transfer_out_account_id, default_transfer_in_account_id, ',
        'sort, enable, recycle_bin, remark, ',
        'creator_id, updater_id, create_time, update_time) ',
        'SELECT ',
        'old.id + @book_shift, ',  -- 应用账本ID偏移
        'old.group_id + @group_shift, ',  -- 应用分组偏移
        'old.name, ',
        'old.default_currency_code, ',
        'IF(old.default_expense_account_id IS NULL, NULL, old.default_expense_account_id + @account_shift), ',  -- 应用账户偏移
        'IF(old.default_income_account_id IS NULL, NULL, old.default_income_account_id + @account_shift), ',
        'IF(old.default_transfer_from_account_id IS NULL, NULL, old.default_transfer_from_account_id + @account_shift), ',
        'IF(old.default_transfer_to_account_id IS NULL, NULL, old.default_transfer_to_account_id + @account_shift), ',
        'old.ranking, ',
        'CAST(old.enable AS UNSIGNED), ',  -- bit转tinyint
        '0, ',  -- recycle_bin默认值
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  -- creator_id
        @new_user_id, ', ',  -- updater_id
        'NOW(), ',  -- create_time
        'NOW() ',   -- update_time
        'FROM ', @old_schema, '.t_user_book AS old ',
        'WHERE old.group_id IN (',
            'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
            'WHERE user_id = ',@old_user_id ,
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置账本表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(book_id), 0) + 1 INTO @next_book_id ',
        'FROM ', @new_schema, '.fortune_book'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_book ',
        'AUTO_INCREMENT = ', @next_book_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- ---------- 迁移分类数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_category ',
        '(category_id, category_type, category_name, book_id, parent_id, ',
        'sort, enable, remark, creator_id, updater_id, create_time, update_time) ',
        'SELECT ',
        'old.id + @category_shift, ',  -- 应用分类ID偏移
        'CASE old.type ',              -- 类型转换
            'WHEN 100 THEN 1 ',          -- 支出分类
            'WHEN 200 THEN 2 ',          -- 收入分类
            'ELSE 0 END, ',            -- 异常处理
        'old.name, ',
        'old.book_id + @book_shift, ', -- 应用账本偏移
        'IFNULL(old.parent_id + @category_shift, -1), ',  -- 父级ID偏移，默认0
        'old.ranking, ',
        'CAST(old.enable AS UNSIGNED), ',  -- bit转tinyint
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  -- creator_id
        @new_user_id, ', ',  -- updater_id
        'NOW(), ',  -- create_time
        'NOW() ',   -- update_time
        'FROM ', @old_schema, '.t_user_category AS old ',
        'WHERE old.book_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_book ',
            'WHERE group_id IN (',
                'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                'WHERE user_id = ',@old_user_id ,
            ') ',
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置分类表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(category_id), 0) + 1 INTO @next_category_id ',
        'FROM ', @new_schema, '.fortune_category'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_category ',
        'AUTO_INCREMENT = ', @next_category_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- ---------- 迁移交易对象 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_payee ',
        '(payee_id, book_id, payee_name, can_expense, can_income, enable, ',
        'sort, remark, creator_id, updater_id, create_time, update_time) ',
        'SELECT ',
        'old.id + @payee_shift, ',    -- 应用交易对象ID偏移
        'old.book_id + @book_shift, ',-- 应用账本偏移
        'old.name, ',
        'CAST(old.can_expense AS UNSIGNED), ',  -- bit转tinyint
        'CAST(old.can_income AS UNSIGNED), ',
        'CAST(old.enable AS UNSIGNED), ',
        'old.ranking, ',
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  -- creator_id
        @new_user_id, ', ',  -- updater_id
        'NOW(), ',  -- create_time
        'NOW() ',   -- update_time
        'FROM ', @old_schema, '.t_user_payee AS old ',
        'WHERE old.book_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_book ',
            'WHERE group_id IN (',
                'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                'WHERE user_id = ',@old_user_id ,
            ') ',
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置交易对象表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(payee_id), 0) + 1 INTO @next_payee_id ',
        'FROM ', @new_schema, '.fortune_payee'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_payee ',
        'AUTO_INCREMENT = ', @next_payee_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- ---------- 迁移标签数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_tag ',
        '(tag_id, tag_name, book_id, parent_id, can_expense, can_income, can_transfer, ',
        'enable, sort, remark, creator_id, updater_id, create_time, update_time) ',
        'SELECT ',
        'old.id + @tag_shift, ',      -- 应用标签ID偏移
        'old.name, ',
        'old.book_id + @book_shift, ',-- 应用账本偏移
        'IFNULL(old.parent_id + @tag_shift, -1), ',  -- 父级ID偏移处理
        'CAST(old.can_expense AS UNSIGNED), ',  -- bit转tinyint
        'CAST(old.can_income AS UNSIGNED), ',
        'CAST(old.can_transfer AS UNSIGNED), ',
        'CAST(old.enable AS UNSIGNED), ',
        'old.ranking, ',
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  -- creator_id
        @new_user_id, ', ',  -- updater_id
        'NOW(), ',  -- create_time
        'NOW() ',   -- update_time
        'FROM ', @old_schema, '.t_user_tag AS old ',
        'WHERE old.book_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_book ',
            'WHERE group_id IN (',
                'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                'WHERE user_id = ',@old_user_id ,
            ') ',
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置标签表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(tag_id), 0) + 1 INTO @next_tag_id ',
        'FROM ', @new_schema, '.fortune_tag'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_tag ',
        'AUTO_INCREMENT = ', @next_tag_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;


    -- ---------- 账单流水数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_bill ',
        '(bill_id, book_id, title, trade_time, account_id, amount, converted_amount, ',
        'payee_id, bill_type, to_account_id, confirm, include, recycle_bin, remark, ',
        'creator_id, updater_id, create_time, update_time, deleted) ',
        'SELECT ',
        'old.id + @bill_shift, ',  -- 应用账单ID偏移
        'old.book_id + @book_shift, ',  -- 应用账本偏移
        'IFNULL(old.title, ''Untitled''), ',
        'FROM_UNIXTIME(old.create_time / 1000), ',  -- 转换毫秒时间戳为datetime
        'IFNULL(old.account_id + @account_shift, NULL), ',  -- 应用账户偏移
        'CAST(old.amount AS DECIMAL(20,4)), ',
        'CAST(old.converted_amount AS DECIMAL(20,4)), ',
        'IFNULL(old.payee_id + @payee_shift, NULL), ',  -- 应用交易对象偏移
        'CASE old.type ',  -- 类型映射
            'WHEN 100 THEN 1 ',  -- 1表示支出
            'WHEN 200 THEN 2 ',  -- 2表示收入
            'WHEN 300 THEN 3 ',  -- 转账
            'ELSE 4 END, ',    -- 其他类型映射为余额调整
        'IFNULL(old.to_id + @account_shift, NULL), ',  -- 转账目标账户偏移
        'CAST(old.confirm AS UNSIGNED), ',  -- bit转tinyint
        'CAST(old.include AS UNSIGNED), ',
        '0, ',  -- recycle_bin默认值
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  -- creator_id
        @new_user_id, ', ',  -- updater_id
        'FROM_UNIXTIME(old.create_time / 1000), ',  -- 创建时间
        'FROM_UNIXTIME(old.insert_at / 1000), ',    -- 更新时间
        '0 ',  -- deleted默认值
        'FROM ', @old_schema, '.t_user_balance_flow AS old ',
        'WHERE old.book_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_book ',
            'WHERE group_id IN (',
                'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                'WHERE user_id = ', @old_user_id,
            ')',
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置账单表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(bill_id), 0) + 1 INTO @next_bill_id ',
        'FROM ', @new_schema, '.fortune_bill'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_bill ',
        'AUTO_INCREMENT = ', @next_bill_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;


    -- ---------- 迁移分类关系数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_category_relation ',
        '(category_relation_id, category_id, bill_id, amount, ',
        'creator_id, updater_id, create_time, update_time, deleted) ',
        'SELECT ',
        'old.id + @category_rel_shift, ',  -- 应用关系表ID偏移
        'old.category_id + @category_shift, ',  -- 应用分类偏移
        'old.balance_flow_id + @bill_shift, ',  -- 应用账单偏移
        'CAST(old.amount AS DECIMAL(20,4)), ',  -- 精度转换
        @new_user_id, ', ',  -- creator_id
        @new_user_id, ', ',  -- updater_id
        'b.create_time, ',  -- 使用关联账单的创建时间
        'b.update_time, ',   -- 使用关联账单的更新时间
        '0 ',                -- deleted默认值
        'FROM ', @old_schema, '.t_user_category_relation AS old ',
        'JOIN ', @new_schema, '.fortune_bill AS b ',  -- 关联新账单表
        'ON old.balance_flow_id + @bill_shift = b.bill_id ',
        'WHERE b.bill_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_balance_flow AS tub ',
            'WHERE tub.book_id IN (',
                'SELECT id FROM ', @old_schema, '.t_user_book ',
                'WHERE group_id IN (',
                    'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                    'WHERE user_id = ',@old_user_id ,
                ') ',
            ')',
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置分类关系表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(category_relation_id), 0) + 1 INTO @next_category_rel_id ',
        'FROM ', @new_schema, '.fortune_category_relation'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_category_relation ',
        'AUTO_INCREMENT = ', @next_category_rel_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;


    -- ---------- 迁移标签关系数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_tag_relation ',
        '(tag_relation_id, bill_id, tag_id, ',
        'creator_id, updater_id, create_time, update_time, deleted) ',
        'SELECT ',
        'old.id + @tag_rel_shift, ',  -- 应用关系表ID偏移
        'old.balance_flow_id + @bill_shift, ',  -- 应用账单偏移
        'old.tag_id + @tag_shift, ',  -- 应用标签偏移
        @new_user_id, ', ',  -- creator_id
        @new_user_id, ', ',  -- updater_id
        'b.create_time, ',  -- 使用关联账单的创建时间
        'b.update_time, ',  -- 使用关联账单的更新时间
        '0 '                -- deleted默认值
        'FROM ', @old_schema, '.t_user_tag_relation AS old ',
        'JOIN ', @new_schema, '.fortune_bill AS b ',  -- 关联新账单表
        'ON old.balance_flow_id + @bill_shift = b.bill_id ',
        'WHERE b.bill_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_balance_flow AS tubf ',
            'WHERE tubf.book_id IN (',
                'SELECT id FROM ', @old_schema, '.t_user_book as tub ',
                'WHERE tub.group_id IN (',
                    'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                    'WHERE user_id = ',@old_user_id ,
                ') ',
            ')',
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置标签关系表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(tag_relation_id), 0) + 1 INTO @next_tag_rel_id ',
        'FROM ', @new_schema, '.fortune_tag_relation'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_tag_relation ',
        'AUTO_INCREMENT = ', @next_tag_rel_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;


    -- ---------- 迁移文件数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_file ',
        '(file_id, bill_id, content_type, file_data, size, original_name, ',
        'creator_id, updater_id, update_time, create_time, deleted) ',
        'SELECT ',
        'old.id + @file_shift, ',          -- 应用文件ID偏移
        'IFNULL(old.flow_id + @bill_shift, 0), ',  -- 处理NULL值并应用账单偏移
        'SUBSTRING(old.content_type, 1, 128), ',  -- 适配新字段长度
        'old.data, ',
        'old.size, ',
        'SUBSTRING(old.original_name, 1, 255), ', -- 截断超长文件名
        @new_user_id, ', ',  -- creator_id（使用映射后的用户ID）
        @new_user_id, ', ',  -- updater_id
        'FROM_UNIXTIME(old.create_time / 1000), ',  -- 更新时间（使用创建时间）
        'FROM_UNIXTIME(old.create_time / 1000), ',  -- 创建时间转换
        '0 ',
        'FROM ', @old_schema, '.t_flow_file AS old ',
        'WHERE old.flow_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_balance_flow AS tubf ',
            'WHERE tubf.book_id IN (',
                'SELECT id FROM ', @old_schema, '.t_user_book as tub ',
                'WHERE tub.group_id IN (',
                    'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                    'WHERE user_id = ',@old_user_id ,
                ') ',
            ')',
        ')'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- 设置文件表自增
    SET @query = CONCAT(
        'SELECT COALESCE(MAX(file_id), 0) + 1 INTO @next_file_id ',
        'FROM ', @new_schema, '.fortune_file'
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @query = CONCAT(
        'ALTER TABLE ', @new_schema, '.fortune_file ',
        'AUTO_INCREMENT = ', @next_file_id
    );
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

END$$

DELIMITER ;

CALL migrate_data();

-- 清理存储过程
DROP PROCEDURE migrate_data;


