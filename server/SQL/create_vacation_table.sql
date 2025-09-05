-- 방학 이용 신청 테이블 생성
CREATE TABLE VacationReservation (
    reservation_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL,
    student_name VARCHAR(50) NOT NULL,
    student_phone VARCHAR(20) NOT NULL,
    reserver_name VARCHAR(50) NOT NULL,
    reserver_relation VARCHAR(20) NOT NULL,
    reserver_phone VARCHAR(20) NOT NULL,
    building VARCHAR(20) NOT NULL,
    room_type VARCHAR(10) NOT NULL,
    guest_count INT NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    total_amount INT NOT NULL,
    status VARCHAR(20) DEFAULT '대기',
    admin_memo TEXT,
    cancel_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_student_id (student_id),
    INDEX idx_status (status),
    INDEX idx_check_in_date (check_in_date)
);

-- 방학 이용 요금 설정 테이블
CREATE TABLE VacationRates (
    rate_id INT AUTO_INCREMENT PRIMARY KEY,
    room_type VARCHAR(10) NOT NULL,
    base_rate INT NOT NULL,
    extra_person_rate INT DEFAULT 5000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_room_type (room_type)
);

-- 기본 요금 데이터 삽입
INSERT INTO VacationRates (room_type, base_rate) VALUES
('1인', 9900),
('2인', 8900),
('3인', 7900); 