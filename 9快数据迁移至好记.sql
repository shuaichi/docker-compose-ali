-- 以下为环境变量，这里需要修改
-- ---------- begin ------------
-- 使用新的数据库
USE fortune_boot;
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
DELIMITER $$

CREATE PROCEDURE migrate_data()
BEGIN
    -- ========== 开启事务 以防执行失败出现脏数据 ==========
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- ========== 第一阶段 设置各个表的最大ID ==========
    -- (保持原样，查询不需要放在事务内)
    SET @query = CONCAT('SELECT COALESCE(MAX(group_id), 0) + 1 INTO @group_shift FROM ', @new_schema, '.fortune_group');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(user_group_relation_id), 0) + 1 INTO @relation_shift FROM ', @new_schema, '.fortune_user_group_relation');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(account_id), 0) + 1 INTO @account_shift FROM ', @new_schema, '.fortune_account');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(book_id), 0) + 1 INTO @book_shift FROM ', @new_schema, '.fortune_book');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(category_id), 0) + 1 INTO @category_shift FROM ', @new_schema, '.fortune_category');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(payee_id), 0) + 1 INTO @payee_shift FROM ', @new_schema, '.fortune_payee');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(tag_id), 0) + 1 INTO @tag_shift FROM ', @new_schema, '.fortune_tag');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(bill_id), 0) + 1 INTO @bill_shift FROM ', @new_schema, '.fortune_bill');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(category_relation_id), 0) + 1 INTO @category_rel_shift FROM ', @new_schema, '.fortune_category_relation');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(tag_relation_id), 0) + 1 INTO @tag_rel_shift FROM ', @new_schema, '.fortune_tag_relation');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(file_id), 0) + 1 INTO @file_shift FROM ', @new_schema, '.fortune_file');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ========== 开启事务 ==========
    START TRANSACTION;

    -- ========== 第二阶段 迁移数据 ==========
    -- ---------- 迁移分组数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_group ',
        '(group_id, group_name, default_currency, enable, remark, default_book_id, creator_id, updater_id, create_time, update_time) ',
        'SELECT old.id + @group_shift, ',
               'old.name, ',
               'old.default_currency_code, ',
               'old.enable, ',
               'old.notes, ',
               'IF(old.default_book_id IS NULL OR old.default_book_id = 0, NULL, old.default_book_id + @book_shift), ', -- ✅ 修复0值风险
                @new_user_id, ', ',  
                @new_user_id, ', ',  
                'NOW(), ',  
                'NOW() ',  
        'FROM ', @old_schema, '.t_user_group AS old ',
        'WHERE EXISTS (',
            'SELECT 1 FROM ', @old_schema, '.t_user_user_group_relation ',
            'WHERE group_id = old.id AND user_id = @old_user_id',
        ')'
    );
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 迁移用户/分组关系数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_user_group_relation ',
        '(user_group_relation_id, role_type, group_id, user_id, default_group, ',
            'creator_id, updater_id, create_time, update_time) ',
        'SELECT old.id + @relation_shift, ',
               'old.role, ',
               'old.group_id + @group_shift, ',
               @new_user_id, ', ',
               'IF(old.group_id = tuu.default_group_id, 1, 0), ',
               @new_user_id, ', ',  
               @new_user_id, ', ',  
               'NOW(), ',  
               'NOW() ',  
        'FROM ', @old_schema, '.t_user_user_group_relation AS old ',
        'INNER JOIN ',@old_schema, '.t_user_user AS tuu ',
        'ON old.user_id = tuu.id ',
        'WHERE old.user_id = @old_user_id'
    );
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 迁移账户数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_account ',
        '(account_id, card_no, account_name, balance, bill_day, can_expense, can_income, ',
        'can_transfer_out, can_transfer_in, credit_limit, currency_code, recycle_bin,enable, ',
        'include, apr, initial_balance, account_type, group_id, sort, remark, ',
        'creator_id, updater_id, create_time, update_time) ',
        'SELECT ',
        'old.id + @account_shift, ',  
        'old.no, ',          
        'old.name, ',
        'CAST(old.balance AS DECIMAL(20,4)), ',
        'CASE WHEN old.bill_day IS NOT NULL AND old.bill_day > 0 THEN ', -- 修复了日期拼装BUG，强制使用01月，防止非法日期报错
            'STR_TO_DATE(',
                'CONCAT(YEAR(NOW()), "-01-", LPAD(LEAST(old.bill_day, 31), 2, "0")), ',
                '"%Y-%m-%d"',
            ') ',
        'ELSE NULL END, ',  
        'old.can_expense, ',
        'old.can_income, ',
        'old.can_transfer_from, ',
        'old.can_transfer_to, ',
        'old.credit_limit, ',
        'old.currency_code, ',
        'CASE old.enable ',
            'WHEN 1 THEN 0 ',  
            'ELSE 1 END, ',
        '1, ',               
        'old.include, ',
        'old.apr, ',
        'CAST(old.initial_balance AS DECIMAL(20,4)), ',
        'CASE old.type ',
            'WHEN 100 THEN 1 ',  
            'WHEN 200 THEN 2 ',
            'WHEN 300 THEN 3 ',  
            'ELSE 4 END, ',
        'old.group_id + @group_shift, ',  
        'old.ranking, ',
        'IFNULL(old.notes,''''), ',  
        @new_user_id, ', ',  
        @new_user_id, ', ',  
        'NOW(), ',  
        'NOW() ',  
        'FROM ', @old_schema, '.t_user_account AS old ',
        'WHERE old.group_id IN (',
            'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
            'WHERE user_id = ',@old_user_id ,
        ')'
    );
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 迁移账本数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_book ',
        '(book_id, group_id, book_name, default_currency, ',
        'default_expense_account_id, default_income_account_id, ',
        'default_transfer_out_account_id, default_transfer_in_account_id, ',
        'sort, recycle_bin, remark, ',
        'creator_id, updater_id, create_time, update_time) ',
        'SELECT ',
        'old.id + @book_shift, ',  
        'old.group_id + @group_shift, ',  
        'old.name, ',
        'old.default_currency_code, ',
        'IF(old.default_expense_account_id IS NULL OR old.default_expense_account_id = 0, NULL, old.default_expense_account_id + @account_shift), ',  
        'IF(old.default_income_account_id IS NULL OR old.default_income_account_id = 0, NULL, old.default_income_account_id + @account_shift), ',
        'IF(old.default_transfer_from_account_id IS NULL OR old.default_transfer_from_account_id = 0, NULL, old.default_transfer_from_account_id + @account_shift), ',
        'IF(old.default_transfer_to_account_id IS NULL OR old.default_transfer_to_account_id = 0, NULL, old.default_transfer_to_account_id + @account_shift), ',
        'old.ranking, ',
        'CASE old.enable ',
            'WHEN 1 THEN 0 ',  
            'ELSE 1 END, ',
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  
        @new_user_id, ', ',  
        'NOW(), ',  
        'NOW() ',   
        'FROM ', @old_schema, '.t_user_book AS old ',
        'WHERE old.group_id IN (',
            'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
            'WHERE user_id = ',@old_user_id ,
        ')'
    );
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 迁移分类数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_category ',
        '(category_id, category_type, category_name, book_id, parent_id, ',
        'sort, recycle_bin, remark, creator_id, updater_id, create_time, update_time) ',
        'SELECT ',
        'old.id + @category_shift, ',  
        'CASE old.type ',              
            'WHEN 100 THEN 1 ',          
            'WHEN 200 THEN 2 ',          
            'ELSE 0 END, ',            
        'old.name, ',
        'old.book_id + @book_shift, ', 
        'IF(old.parent_id = 0 OR old.parent_id IS NULL, -1, old.parent_id + @category_shift), ',
        'old.ranking, ',
        'CASE old.enable ',
            'WHEN 1 THEN 0 ',  
            'ELSE 1 END, ',
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  
        @new_user_id, ', ',  
        'NOW(), ',  
        'NOW() ',   
        'FROM ', @old_schema, '.t_user_category AS old ',
        'WHERE old.book_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_book ',
            'WHERE group_id IN (',
                'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                'WHERE user_id = ',@old_user_id ,
            ') ',
        ')'
    );
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 迁移交易对象 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_payee ',
        '(payee_id, book_id, payee_name, can_expense, can_income, recycle_bin, ',
        'sort, remark, creator_id, updater_id, create_time, update_time) ',
        'SELECT ',
        'old.id + @payee_shift, ',    
        'old.book_id + @book_shift, ',
        'old.name, ',
        'CAST(old.can_expense AS UNSIGNED), ',  
        'CAST(old.can_income AS UNSIGNED), ',
        'CASE old.enable ',
            'WHEN 1 THEN 0 ',  
            'ELSE 1 END, ',
        'old.ranking, ',
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  
        @new_user_id, ', ',  
        'NOW(), ',  
        'NOW() ',   
        'FROM ', @old_schema, '.t_user_payee AS old ',
        'WHERE old.book_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_book ',
            'WHERE group_id IN (',
                'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                'WHERE user_id = ',@old_user_id ,
            ') ',
        ')'
    );
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 迁移标签数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_tag ',
        '(tag_id, tag_name, book_id, parent_id, can_expense, can_income, can_transfer, ',
        'recycle_bin, sort, remark, creator_id, updater_id, create_time, update_time) ',
        'SELECT ',
        'old.id + @tag_shift, ',      
        'old.name, ',
        'old.book_id + @book_shift, ',
        'IF(old.parent_id = 0 OR old.parent_id IS NULL, -1, old.parent_id + @tag_shift), ', 
        'CAST(old.can_expense AS UNSIGNED), ',  
        'CAST(old.can_income AS UNSIGNED), ',
        'CAST(old.can_transfer AS UNSIGNED), ',
        'CASE old.enable ',
            'WHEN 1 THEN 0 ',  
            'ELSE 1 END, ',
        'old.ranking, ',
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  
        @new_user_id, ', ',  
        'NOW(), ',  
        'NOW() ',   
        'FROM ', @old_schema, '.t_user_tag AS old ',
        'WHERE old.book_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_book ',
            'WHERE group_id IN (',
                'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                'WHERE user_id = ',@old_user_id ,
            ') ',
        ')'
    );
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 账单流水数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_bill ',
        '(bill_id, book_id, title, trade_time, account_id, amount, converted_amount, ',
        'payee_id, bill_type, to_account_id, confirm, include, recycle_bin, remark, ',
        'creator_id, updater_id, create_time, update_time, deleted) ',
        'SELECT ',
        'old.id + @bill_shift, ',  
        'old.book_id + @book_shift, ',  
        'IFNULL(old.title, ''Untitled''), ',
        'FROM_UNIXTIME(old.create_time / 1000), ',  
        'IF(old.account_id IS NULL OR old.account_id = 0, NULL, old.account_id + @account_shift), ',  
        'CAST(old.amount AS DECIMAL(20,4)), ',
        'CAST(old.converted_amount AS DECIMAL(20,4)), ',
        'IF(old.payee_id IS NULL OR old.payee_id = 0, NULL, old.payee_id + @payee_shift), ',  
        'CASE old.type ',  
            'WHEN 100 THEN 1 ',  
            'WHEN 200 THEN 2 ',  
            'WHEN 300 THEN 3 ',  
            'ELSE 4 END, ',    
        'IF(old.to_id IS NULL OR old.to_id = 0, NULL, old.to_id + @account_shift), ',
        'CAST(old.confirm AS UNSIGNED), ',  
        'CAST(old.include AS UNSIGNED), ',
        '0, ',  
        'IFNULL(old.notes, ''''), ',
        @new_user_id, ', ',  
        @new_user_id, ', ',  
        'FROM_UNIXTIME(old.create_time / 1000), ',  
        'FROM_UNIXTIME(old.insert_at / 1000), ',    
        '0 ',  
        'FROM ', @old_schema, '.t_user_balance_flow AS old ',
        'WHERE old.book_id IN (',
            'SELECT id FROM ', @old_schema, '.t_user_book ',
            'WHERE group_id IN (',
                'SELECT group_id FROM ', @old_schema, '.t_user_user_group_relation ',
                'WHERE user_id = ', @old_user_id,
            ')',
        ')'
    );
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 迁移分类关系数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_category_relation ',
        '(category_relation_id, category_id, bill_id, amount, ',
        'creator_id, updater_id, create_time, update_time, deleted) ',
        'SELECT ',
        'old.id + @category_rel_shift, ',  
        'old.category_id + @category_shift, ',  
        'old.balance_flow_id + @bill_shift, ',  
        'CAST(old.amount AS DECIMAL(20,4)), ',  
        @new_user_id, ', ',  
        @new_user_id, ', ',  
        'FROM_UNIXTIME(b.create_time / 1000), ',  
        'FROM_UNIXTIME(b.insert_at / 1000), ',    
        '0 ',  
        'FROM ', @old_schema, '.t_user_category_relation AS old ',
        'JOIN ', @old_schema, '.t_user_balance_flow AS b ',  
        'ON old.balance_flow_id = b.id ',
        'WHERE b.id IN (',
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
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 迁移标签关系数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_tag_relation ',
        '(tag_relation_id, bill_id, tag_id, ',
        'creator_id, updater_id, create_time, update_time, deleted) ',
        'SELECT ',
        'old.id + @tag_rel_shift, ',  
        'old.balance_flow_id + @bill_shift, ',  
        'old.tag_id + @tag_shift, ',  
        @new_user_id, ', ',  
        @new_user_id, ', ',  
        'FROM_UNIXTIME(b.create_time / 1000), ',  
        'FROM_UNIXTIME(b.insert_at / 1000), ',    
        '0 ',               
        'FROM ', @old_schema, '.t_user_tag_relation AS old ',
        'JOIN ', @old_schema, '.t_user_balance_flow AS b ',  
        'ON old.balance_flow_id = b.id ',
        'WHERE b.id IN (',
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
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ---------- 迁移文件数据 ----------
    SET @query = CONCAT(
        'INSERT INTO ', @new_schema, '.fortune_file ',
        '(file_id, bill_id, content_type, file_data, size, original_name, ',
        'creator_id, updater_id, update_time, create_time, deleted) ',
        'SELECT ',
        'old.id + @file_shift, ',          
        'IF(old.flow_id IS NULL OR old.flow_id = 0, 0, old.flow_id + @bill_shift), ',
        'SUBSTRING(old.content_type, 1, 128), ',  
        'old.data, ',
        'old.size, ',
        'SUBSTRING(old.original_name, 1, 255), ', 
        @new_user_id, ', ',  
        @new_user_id, ', ',  
        'FROM_UNIXTIME(old.create_time / 1000), ',  
        'FROM_UNIXTIME(old.create_time / 1000), ',  
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
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    
    -- ======== 最后处理默认分组冲突 ========
    -- 清除新系统自带默认分组
    SET @query = CONCAT(
        'UPDATE ', @new_schema, '.fortune_user_group_relation ',
        'SET default_group = 0 ',
        'WHERE user_id = ', @new_user_id,
        '  AND group_id < ', @group_shift,
        '  AND EXISTS (',
        '      SELECT 1 FROM (',
        '          SELECT 1 FROM ', @new_schema, '.fortune_user_group_relation ',
        '          WHERE user_id = ', @new_user_id,
        '            AND group_id >= ', @group_shift,
        '            AND default_group = 1',
        '      ) AS tmp',
        '  )'
    );
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    -- ========== 数据完成迁移 提交事务 ==========
    -- 必须在 DDL（ALTER TABLE）执行前提交，否则事务会因为隐式提交而失效
    COMMIT;


    -- ========== 第三阶段 统一处理自增ID (DDL不能放在事务逻辑中) ==========
    SET @query = CONCAT('SELECT COALESCE(MAX(group_id), 0) + 1 INTO @next_group_id FROM ', @new_schema, '.fortune_group');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_group AUTO_INCREMENT = ', @next_group_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(user_group_relation_id), 0) + 1 INTO @next_rel_id FROM ', @new_schema, '.fortune_user_group_relation');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_user_group_relation AUTO_INCREMENT = ', @next_rel_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(account_id), 0) + 1 INTO @next_account_id FROM ', @new_schema, '.fortune_account');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_account AUTO_INCREMENT = ', @next_account_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(book_id), 0) + 1 INTO @next_book_id FROM ', @new_schema, '.fortune_book');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_book AUTO_INCREMENT = ', @next_book_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(category_id), 0) + 1 INTO @next_category_id FROM ', @new_schema, '.fortune_category');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_category AUTO_INCREMENT = ', @next_category_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(payee_id), 0) + 1 INTO @next_payee_id FROM ', @new_schema, '.fortune_payee');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_payee AUTO_INCREMENT = ', @next_payee_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(tag_id), 0) + 1 INTO @next_tag_id FROM ', @new_schema, '.fortune_tag');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_tag AUTO_INCREMENT = ', @next_tag_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(bill_id), 0) + 1 INTO @next_bill_id FROM ', @new_schema, '.fortune_bill');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_bill AUTO_INCREMENT = ', @next_bill_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(category_relation_id), 0) + 1 INTO @next_category_rel_id FROM ', @new_schema, '.fortune_category_relation');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_category_relation AUTO_INCREMENT = ', @next_category_rel_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(tag_relation_id), 0) + 1 INTO @next_tag_rel_id FROM ', @new_schema, '.fortune_tag_relation');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_tag_relation AUTO_INCREMENT = ', @next_tag_rel_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @query = CONCAT('SELECT COALESCE(MAX(file_id), 0) + 1 INTO @next_file_id FROM ', @new_schema, '.fortune_file');
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    SET @query = CONCAT('ALTER TABLE ', @new_schema, '.fortune_file AUTO_INCREMENT = ', @next_file_id);
    PREPARE stmt FROM @query; EXECUTE stmt; DEALLOCATE PREPARE stmt;

END$$

DELIMITER ;

CALL migrate_data();

-- 清理存储过程
DROP PROCEDURE migrate_data;
