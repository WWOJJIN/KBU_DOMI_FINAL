-- 석식 관리 시스템 개선: status 기반에서 결제/환불 중심으로 변경
-- 2025-06-25

-- 1. Dinner 테이블에서 불필요한 컬럼 제거
ALTER TABLE Dinner 
    DROP COLUMN status,
    DROP COLUMN manual_payment_date,
    DROP COLUMN manual_refund_date;

-- 2. Dinner_Payment 테이블에 amount 기본값 설정 (선택사항)
-- ALTER TABLE Dinner_Payment MODIFY amount int NOT NULL DEFAULT 150000;

-- 3. AS(After_Service) 테이블에 반려 사유 컬럼 추가
-- 2025-06-25
ALTER TABLE After_Service ADD COLUMN rejection_reason TEXT;

-- 참고: 
-- - 상태는 Dinner_Payment 테이블의 결제/환불 이력으로 동적 결정
-- - 신청만 있으면 '신청', 결제 있으면 '결제완료', 환불 있으면 '환불완료'
-- - 기간 제한은 매월 1일~15일 자동 설정 (관리자가 수동 변경 가능) 
-- - AS 반려 시 관리자가 사유를 입력할 수 있음 

-- 점호 기록 테이블 생성
CREATE TABLE IF NOT EXISTS RollCall (
    rollcall_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL,
    rollcall_date DATE NOT NULL,
    rollcall_time TIME NOT NULL,
    location_lat DECIMAL(10, 8),           -- GPS 위도
    location_lng DECIMAL(11, 8),           -- GPS 경도
    distance_from_campus DECIMAL(8, 2),    -- 캠퍼스에서 거리(미터)
    rollcall_type ENUM('자동', '수동') DEFAULT '자동',
    processed_by VARCHAR(50),              -- 수동 점호 시 처리한 관리자
    reason TEXT,                           -- 수동 점호 사유
    reg_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES Domi_Students(student_id),
    UNIQUE KEY unique_daily_rollcall (student_id, rollcall_date)
);

-- 점호 설정 테이블 (점호 시간 관리용)
CREATE TABLE IF NOT EXISTS RollCallSettings (
    setting_id INT AUTO_INCREMENT PRIMARY KEY,
    setting_name VARCHAR(50) NOT NULL UNIQUE,
    setting_value VARCHAR(255) NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 기본 점호 설정값 삽입
INSERT INTO RollCallSettings (setting_name, setting_value, description) VALUES
('rollcall_start_time', '23:50:00', '점호 시작 시간'),
('rollcall_end_time', '00:10:00', '점호 종료 시간'),  
('campus_lat', '37.735700', '캠퍼스 위도'),
('campus_lng', '127.210523', '캠퍼스 경도'),
('allowed_distance', '50', '허용 거리(미터)'),
('auto_rollcall_enabled', 'true', '자동 점호 활성화 여부')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 점호 현황 통계를 위한 뷰 생성
CREATE OR REPLACE VIEW RollCallStatus AS
SELECT 
    DATE(NOW()) as today,
    COUNT(DISTINCT ds.student_id) as total_students,
    COUNT(DISTINCT rc.student_id) as completed_rollcalls,
    (COUNT(DISTINCT ds.student_id) - COUNT(DISTINCT rc.student_id)) as pending_rollcalls
FROM Domi_Students ds
LEFT JOIN RollCall rc ON ds.student_id = rc.student_id 
    AND rc.rollcall_date = DATE(NOW())
WHERE ds.stat = '입주중';

-- 샘플 점호 데이터 삽입 (테스트용)
INSERT INTO RollCall (student_id, rollcall_date, rollcall_time, location_lat, location_lng, distance_from_campus, rollcall_type) VALUES
('1', CURDATE(), '00:05:30', 37.735800, 127.210400, 25.5, '자동'),
('20240123', CURDATE(), '00:03:15', 37.735650, 127.210600, 45.2, '자동'),
('20230046', CURDATE() - INTERVAL 1 DAY, '00:07:45', 37.735900, 127.210300, 35.8, '자동'); 