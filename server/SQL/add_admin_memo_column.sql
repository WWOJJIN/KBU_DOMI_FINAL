-- Firstin 테이블에 admin_memo 컬럼 추가
ALTER TABLE Firstin ADD COLUMN admin_memo TEXT DEFAULT NULL;

-- 인덱스도 추가 (검색 성능 향상)
ALTER TABLE Firstin ADD INDEX idx_reg_dt (reg_dt);
ALTER TABLE Firstin ADD INDEX idx_status_distance (status, distance); 