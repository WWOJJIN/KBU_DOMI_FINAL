-- 룸메이트 신청 상태변경 이력 테이블 생성
CREATE TABLE IF NOT EXISTS Roommate_Request_History (
    id INT AUTO_INCREMENT PRIMARY KEY,
    request_id INT NOT NULL COMMENT '룸메이트 신청 ID (Roommate_Requests.id 참조)',
    requester_id VARCHAR(20) NOT NULL COMMENT '신청자 학번',
    requested_id VARCHAR(20) NOT NULL COMMENT '피신청자 학번',
    previous_status VARCHAR(20) COMMENT '이전 상태',
    new_status VARCHAR(20) NOT NULL COMMENT '변경된 상태',
    change_reason VARCHAR(255) COMMENT '변경 사유 (취소, 거절, 수락 등)',
    changed_by VARCHAR(20) NOT NULL COMMENT '변경자 (student_id 또는 admin)',
    changed_by_type ENUM('student', 'admin') NOT NULL COMMENT '변경자 유형',
    admin_memo TEXT COMMENT '관리자 메모',
    room_assigned VARCHAR(100) COMMENT '배정된 방 정보 (상태가 confirmed일 때)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '이력 생성 시간',
    
    INDEX idx_request_id (request_id),
    INDEX idx_requester_id (requester_id),
    INDEX idx_requested_id (requested_id),
    INDEX idx_status_change (previous_status, new_status),
    INDEX idx_created_at (created_at),
    INDEX idx_changed_by (changed_by),
    
    FOREIGN KEY (request_id) REFERENCES Roommate_Requests(id) ON DELETE CASCADE
) COMMENT='룸메이트 신청 상태변경 이력 테이블';

-- 기존 Roommate_Requests 테이블에 이력 기록을 위한 트리거 생성
DELIMITER $$

-- 상태 변경 시 이력 자동 기록 트리거
CREATE TRIGGER IF NOT EXISTS roommate_status_change_trigger
AFTER UPDATE ON Roommate_Requests
FOR EACH ROW
BEGIN
    -- 상태가 변경된 경우에만 이력 기록
    IF OLD.status != NEW.status THEN
        INSERT INTO Roommate_Request_History (
            request_id,
            requester_id,
            requested_id,
            previous_status,
            new_status,
            change_reason,
            changed_by,
            changed_by_type,
            created_at
        ) VALUES (
            NEW.id,
            NEW.requester_id,
            NEW.requested_id,
            OLD.status,
            NEW.status,
            '상태 변경',
            'system',
            'system',
            NOW()
        );
    END IF;
END$$

-- 신청 생성 시 초기 이력 기록 트리거
CREATE TRIGGER IF NOT EXISTS roommate_request_created_trigger
AFTER INSERT ON Roommate_Requests
FOR EACH ROW
BEGIN
    INSERT INTO Roommate_Request_History (
        request_id,
        requester_id,
        requested_id,
        previous_status,
        new_status,
        change_reason,
        changed_by,
        changed_by_type,
        created_at
    ) VALUES (
        NEW.id,
        NEW.requester_id,
        NEW.requested_id,
        NULL,
        NEW.status,
        '신청 생성',
        NEW.requester_id,
        'student',
        NOW()
    );
END$$

DELIMITER ;

-- 샘플 데이터 (테스트용)
INSERT INTO Roommate_Request_History (
    request_id, requester_id, requested_id, previous_status, new_status, 
    change_reason, changed_by, changed_by_type, created_at
) VALUES 
(1, '1', '2', NULL, 'pending', '신청 생성', '1', 'student', NOW() - INTERVAL 7 DAY),
(1, '1', '2', 'pending', 'accepted', '수락', '2', 'student', NOW() - INTERVAL 6 DAY),
(1, '1', '2', 'accepted', 'confirmed', '관리자 배정완료', 'admin', 'admin', NOW() - INTERVAL 5 DAY),
(2, '2', '1', NULL, 'pending', '신청 생성', '2', 'student', NOW() - INTERVAL 4 DAY),
(2, '2', '1', 'pending', 'rejected', '거절', '1', 'student', NOW() - INTERVAL 3 DAY),
(3, '1', '3', NULL, 'pending', '신청 생성', '1', 'student', NOW() - INTERVAL 2 DAY),
(4, '3', '1', NULL, 'pending', '신청 생성', '3', 'student', NOW() - INTERVAL 1 DAY);

-- 설정 테이블 생성 (재신청 제한 기간 등 관리자 설정 저장용)
CREATE TABLE IF NOT EXISTS Settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_setting_key (setting_key)
);

-- 기본 설정값 삽입
INSERT IGNORE INTO Settings (setting_key, setting_value, description) VALUES
('roommate_reapply_period', '30', '룸메이트 관계 해지 후 재신청 제한 기간 (일)'); 