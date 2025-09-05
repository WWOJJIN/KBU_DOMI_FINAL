-- 자동배정 시스템에 필요한 테이블 생성 스크립트

-- 1. Room_Info 테이블 (방 정보)
CREATE TABLE IF NOT EXISTS Room_Info (
    room_id INT AUTO_INCREMENT PRIMARY KEY,
    building VARCHAR(20) NOT NULL COMMENT '건물명 (숭례원/양덕원)',
    floor INT NOT NULL COMMENT '층수',
    room_number VARCHAR(10) NOT NULL COMMENT '호실번호',
    room_type VARCHAR(20) NOT NULL COMMENT '방타입 (1인실/2인실/3인실/룸메이트/방학이용)',
    capacity INT NOT NULL COMMENT '수용인원',
    gender VARCHAR(10) NOT NULL COMMENT '성별 (남자/여자)',
    smoking_allowed BOOLEAN DEFAULT FALSE COMMENT '흡연허용여부',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_room (building, room_number)
) COMMENT='방 정보 테이블';

-- 2. System_Settings 테이블 (시스템 설정)
CREATE TABLE IF NOT EXISTS System_Settings (
    setting_id INT AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE COMMENT '설정 키',
    setting_value TEXT COMMENT '설정 값',
    description TEXT COMMENT '설정 설명',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='시스템 설정 테이블';

-- 3. Checkin_Status_History 테이블 (입실신청 상태 변경 이력)
CREATE TABLE IF NOT EXISTS Checkin_Status_History (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL COMMENT '학번',
    old_status VARCHAR(20) COMMENT '이전 상태',
    new_status VARCHAR(20) NOT NULL COMMENT '새로운 상태',
    changed_by VARCHAR(50) COMMENT '변경자',
    reason TEXT COMMENT '변경 사유',
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '변경 시간',
    INDEX idx_student_id (student_id),
    INDEX idx_changed_at (changed_at)
) COMMENT='입실신청 상태 변경 이력 테이블';

-- 4. Assignment_History 테이블 (배정 이력) - 선택적
CREATE TABLE IF NOT EXISTS Assignment_History (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL COMMENT '학번',
    action VARCHAR(20) NOT NULL COMMENT '액션 (assigned/cancelled/cancelled_pair)',
    room_number VARCHAR(10) COMMENT '방번호',
    reason TEXT COMMENT '사유',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_student_id (student_id),
    INDEX idx_created_at (created_at)
) COMMENT='배정 이력 테이블';

-- 기본 방 정보 데이터 삽입 (예시)
INSERT IGNORE INTO Room_Info (building, floor, room_number, room_type, capacity, gender, smoking_allowed) VALUES
-- 숭례원 (남자기숙사)
-- 6층 1인실
('숭례원', 6, '601', '1인실', 1, '남자', FALSE),
('숭례원', 6, '602', '1인실', 1, '남자', FALSE),
('숭례원', 6, '603', '1인실', 1, '남자', FALSE),
('숭례원', 6, '604', '1인실', 1, '남자', FALSE),
('숭례원', 6, '605', '1인실', 1, '남자', FALSE),
('숭례원', 6, '606', '1인실', 1, '남자', FALSE),
('숭례원', 6, '607', '1인실', 1, '남자', FALSE),
('숭례원', 6, '608', '1인실', 1, '남자', FALSE),
('숭례원', 6, '609', '1인실', 1, '남자', FALSE),
('숭례원', 6, '610', '1인실', 1, '남자', FALSE),

-- 7층 2인실
('숭례원', 7, '701', '2인실', 2, '남자', FALSE),
('숭례원', 7, '702', '2인실', 2, '남자', FALSE),
('숭례원', 7, '703', '2인실', 2, '남자', FALSE),
('숭례원', 7, '704', '2인실', 2, '남자', FALSE),
('숭례원', 7, '705', '2인실', 2, '남자', FALSE),
('숭례원', 7, '706', '2인실', 2, '남자', FALSE),
('숭례원', 7, '707', '2인실', 2, '남자', FALSE),
('숭례원', 7, '708', '2인실', 2, '남자', FALSE),
('숭례원', 7, '709', '2인실', 2, '남자', FALSE),
('숭례원', 7, '710', '2인실', 2, '남자', FALSE),

-- 8층 3인실
('숭례원', 8, '801', '3인실', 3, '남자', FALSE),
('숭례원', 8, '802', '3인실', 3, '남자', FALSE),
('숭례원', 8, '803', '3인실', 3, '남자', FALSE),
('숭례원', 8, '804', '3인실', 3, '남자', FALSE),
('숭례원', 8, '805', '3인실', 3, '남자', FALSE),
('숭례원', 8, '806', '3인실', 3, '남자', FALSE),
('숭례원', 8, '807', '3인실', 3, '남자', FALSE),
('숭례원', 8, '808', '3인실', 3, '남자', FALSE),

-- 9층 룸메이트
('숭례원', 9, '901', '룸메이트', 2, '남자', FALSE),
('숭례원', 9, '902', '룸메이트', 2, '남자', FALSE),
('숭례원', 9, '903', '룸메이트', 2, '남자', FALSE),
('숭례원', 9, '904', '룸메이트', 2, '남자', FALSE),
('숭례원', 9, '905', '룸메이트', 2, '남자', FALSE),
('숭례원', 9, '906', '룸메이트', 2, '남자', FALSE),
('숭례원', 9, '907', '룸메이트', 2, '남자', FALSE),
('숭례원', 9, '908', '룸메이트', 2, '남자', FALSE),
('숭례원', 9, '909', '룸메이트', 2, '남자', FALSE),
('숭례원', 9, '910', '룸메이트', 2, '남자', FALSE),

-- 10층 방학이용
('숭례원', 10, '1001', '방학이용', 1, '남자', FALSE),
('숭례원', 10, '1002', '방학이용', 1, '남자', FALSE),
('숭례원', 10, '1003', '방학이용', 1, '남자', FALSE),
('숭례원', 10, '1004', '방학이용', 1, '남자', FALSE),
('숭례원', 10, '1005', '방학이용', 1, '남자', FALSE),

-- 양덕원 (여자기숙사)
-- 6층 1인실
('양덕원', 6, '601', '1인실', 1, '여자', FALSE),
('양덕원', 6, '602', '1인실', 1, '여자', FALSE),
('양덕원', 6, '603', '1인실', 1, '여자', FALSE),
('양덕원', 6, '604', '1인실', 1, '여자', FALSE),
('양덕원', 6, '605', '1인실', 1, '여자', FALSE),
('양덕원', 6, '606', '1인실', 1, '여자', FALSE),
('양덕원', 6, '607', '1인실', 1, '여자', FALSE),
('양덕원', 6, '608', '1인실', 1, '여자', FALSE),
('양덕원', 6, '609', '1인실', 1, '여자', FALSE),
('양덕원', 6, '610', '1인실', 1, '여자', FALSE),

-- 7층 2인실
('양덕원', 7, '701', '2인실', 2, '여자', FALSE),
('양덕원', 7, '702', '2인실', 2, '여자', FALSE),
('양덕원', 7, '703', '2인실', 2, '여자', FALSE),
('양덕원', 7, '704', '2인실', 2, '여자', FALSE),
('양덕원', 7, '705', '2인실', 2, '여자', FALSE),
('양덕원', 7, '706', '2인실', 2, '여자', FALSE),
('양덕원', 7, '707', '2인실', 2, '여자', FALSE),
('양덕원', 7, '708', '2인실', 2, '여자', FALSE),
('양덕원', 7, '709', '2인실', 2, '여자', FALSE),
('양덕원', 7, '710', '2인실', 2, '여자', FALSE),

-- 8층 3인실
('양덕원', 8, '801', '3인실', 3, '여자', FALSE),
('양덕원', 8, '802', '3인실', 3, '여자', FALSE),
('양덕원', 8, '803', '3인실', 3, '여자', FALSE),
('양덕원', 8, '804', '3인실', 3, '여자', FALSE),
('양덕원', 8, '805', '3인실', 3, '여자', FALSE),
('양덕원', 8, '806', '3인실', 3, '여자', FALSE),
('양덕원', 8, '807', '3인실', 3, '여자', FALSE),
('양덕원', 8, '808', '3인실', 3, '여자', FALSE),

-- 9층 룸메이트
('양덕원', 9, '901', '룸메이트', 2, '여자', FALSE),
('양덕원', 9, '902', '룸메이트', 2, '여자', FALSE),
('양덕원', 9, '903', '룸메이트', 2, '여자', FALSE),
('양덕원', 9, '904', '룸메이트', 2, '여자', FALSE),
('양덕원', 9, '905', '룸메이트', 2, '여자', FALSE),
('양덕원', 9, '906', '룸메이트', 2, '여자', FALSE),
('양덕원', 9, '907', '룸메이트', 2, '여자', FALSE),
('양덕원', 9, '908', '룸메이트', 2, '여자', FALSE),
('양덕원', 9, '909', '룸메이트', 2, '여자', FALSE),
('양덕원', 9, '910', '룸메이트', 2, '여자', FALSE),

-- 10층 방학이용
('양덕원', 10, '1001', '방학이용', 1, '여자', FALSE),
('양덕원', 10, '1002', '방학이용', 1, '여자', FALSE),
('양덕원', 10, '1003', '방학이용', 1, '여자', FALSE),
('양덕원', 10, '1004', '방학이용', 1, '여자', FALSE),
('양덕원', 10, '1005', '방학이용', 1, '여자', FALSE);

-- 기본 시스템 설정 삽입
INSERT IGNORE INTO System_Settings (setting_key, setting_value, description) VALUES
('assignment_priority_roommate', 'true', '룸메이트 우선 배정 여부'),
('assignment_priority_smoking_match', 'true', '흡연 여부 매칭 우선 여부'),
('assignment_priority_building_preference', 'true', '건물 선호도 우선 여부'),
('assignment_allow_cross_building', 'false', '건물 간 배정 허용 여부'),
('assignment_max_batch_size', '50', '한 번에 처리할 최대 배정 건수'); 