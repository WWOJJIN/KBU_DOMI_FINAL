-- 건물별 점호 설정 테이블 생성
CREATE TABLE IF NOT EXISTS DormitoryBuildings (
    building_id INT AUTO_INCREMENT PRIMARY KEY,
    building_name VARCHAR(50) NOT NULL UNIQUE,
    campus_lat DECIMAL(10, 8) NOT NULL,
    campus_lng DECIMAL(11, 8) NOT NULL,
    allowed_distance DECIMAL(8, 2) DEFAULT 50.0,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 기본 기숙사 건물 정보 삽입
INSERT INTO DormitoryBuildings (building_name, campus_lat, campus_lng, allowed_distance, description) VALUES
('양덕원', 37.735700, 127.210523, 50.0, '양덕원 기숙사 건물'),
('숭례원', 37.736200, 127.211000, 50.0, '숭례원 기숙사 건물')
ON DUPLICATE KEY UPDATE 
    campus_lat = VALUES(campus_lat),
    campus_lng = VALUES(campus_lng),
    allowed_distance = VALUES(allowed_distance);

-- RollCall 테이블에 건물 정보 추가
ALTER TABLE RollCall ADD COLUMN IF NOT EXISTS building_name VARCHAR(50);

-- 기존 점호 기록에 건물 정보 업데이트 (학생의 dorm_building 기반)
UPDATE RollCall rc
JOIN Domi_Students ds ON rc.student_id = ds.student_id
SET rc.building_name = ds.dorm_building
WHERE rc.building_name IS NULL;

-- 점호 설정 테이블에 건물별 설정 추가
INSERT INTO RollCallSettings (setting_name, setting_value, description) VALUES
('yangdeok_lat', '37.735700', '양덕원 위도'),
('yangdeok_lng', '127.210523', '양덕원 경도'), 
('yangdeok_distance', '50', '양덕원 허용 거리(미터)'),
('sungrae_lat', '37.736200', '숭례원 위도'),
('sungrae_lng', '127.211000', '숭례원 경도'),
('sungrae_distance', '50', '숭례원 허용 거리(미터)')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 점호 현황 통계를 위한 건물별 뷰 생성
CREATE OR REPLACE VIEW RollCallStatusByBuilding AS
SELECT 
    ds.dorm_building as building_name,
    DATE(NOW()) as today,
    COUNT(DISTINCT ds.student_id) as total_students,
    COUNT(DISTINCT rc.student_id) as completed_rollcalls,
    (COUNT(DISTINCT ds.student_id) - COUNT(DISTINCT rc.student_id)) as pending_rollcalls,
    ROUND((COUNT(DISTINCT rc.student_id) / COUNT(DISTINCT ds.student_id) * 100), 1) as completion_rate
FROM Domi_Students ds
LEFT JOIN RollCall rc ON ds.student_id = rc.student_id 
    AND rc.rollcall_date = DATE(NOW())
WHERE ds.stat = '입주중' AND ds.dorm_building IS NOT NULL
GROUP BY ds.dorm_building; 