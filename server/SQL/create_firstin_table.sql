-- Firstin 테이블 생성 (신입생 입주신청)
CREATE TABLE IF NOT EXISTS Firstin (
    id INT AUTO_INCREMENT PRIMARY KEY,
    recruit_type VARCHAR(20) DEFAULT '1차',
    year VARCHAR(10) DEFAULT '2025',
    semester VARCHAR(20) DEFAULT '1학기',
    student_id VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL,
    birth_date DATE,
    gender VARCHAR(10) NOT NULL,
    nationality VARCHAR(20) DEFAULT '대한민국',
    grade VARCHAR(20) DEFAULT '1학년',
    department VARCHAR(50) NOT NULL,
    passport_num VARCHAR(50),
    applicant_type VARCHAR(20) DEFAULT '내국인',
    address_basic VARCHAR(200),
    address_detail VARCHAR(200),
    postal_code VARCHAR(20),
    tel_home VARCHAR(20),
    tel_mobile VARCHAR(20) NOT NULL,
    guardian_name VARCHAR(50),
    guardian_relation VARCHAR(20),
    guardian_phone VARCHAR(20),
    basic_living_support BOOLEAN DEFAULT FALSE,
    disabled BOOLEAN DEFAULT FALSE,
    reg_dt DATETIME DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT '신청',
    distance FLOAT DEFAULT NULL,
    admin_memo TEXT,
    INDEX idx_student_id (student_id),
    INDEX idx_status (status),
    INDEX idx_distance (distance)
);

-- 상태별 인덱스 추가 (성능 최적화)
ALTER TABLE Firstin ADD INDEX idx_status_distance (status, distance);

-- 거리 기준 자동 선별을 위한 뷰 생성
CREATE OR REPLACE VIEW Firstin_RankedByDistance AS
SELECT 
    id, student_id, name, department, address_basic, tel_mobile,
    status, distance, reg_dt,
    ROW_NUMBER() OVER (ORDER BY distance DESC) as distance_rank
FROM Firstin 
WHERE distance IS NOT NULL 
ORDER BY distance DESC;

-- 기숙사 관련 컬럼 추가 (2025년 6월 29일 추가)
ALTER TABLE Firstin ADD COLUMN IF NOT EXISTS dorm_building VARCHAR(50) DEFAULT NULL;
ALTER TABLE Firstin ADD COLUMN IF NOT EXISTS room_type VARCHAR(20) DEFAULT NULL;
ALTER TABLE Firstin ADD COLUMN IF NOT EXISTS smoking_status VARCHAR(10) DEFAULT '비흡연';
ALTER TABLE Firstin ADD COLUMN IF NOT EXISTS bank VARCHAR(50) DEFAULT NULL;
ALTER TABLE Firstin ADD COLUMN IF NOT EXISTS account_num VARCHAR(50) DEFAULT NULL;
ALTER TABLE Firstin ADD COLUMN IF NOT EXISTS account_holder VARCHAR(50) DEFAULT NULL; 