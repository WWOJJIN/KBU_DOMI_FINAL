-- 룸메이트 신청 데이터에 pair_id와 roommate_type 설정
-- 기존 데이터 마이그레이션 스크립트

-- 1. 상호 동의된 룸메이트 쌍에 pair_id 생성
UPDATE Roommate_Requests 
SET pair_id = CONCAT('pair_', id), 
    roommate_type = 'mutual'
WHERE status IN ('confirmed', 'accepted') 
  AND is_active = 1
  AND pair_id IS NULL;

-- 2. 일방향 신청에 roommate_type 설정
UPDATE Roommate_Requests 
SET roommate_type = 'one-way'
WHERE status = 'pending' 
  AND is_active = 1
  AND roommate_type IS NULL;

-- 3. 거절된 신청에 roommate_type 설정
UPDATE Roommate_Requests 
SET roommate_type = 'rejected'
WHERE status = 'rejected' 
  AND roommate_type IS NULL;

-- 4. 취소된 신청에 roommate_type 설정
UPDATE Roommate_Requests 
SET roommate_type = 'canceled'
WHERE status = 'canceled' 
  AND roommate_type IS NULL;

-- 5. 같은 pair_id를 가진 상대방 신청도 업데이트
UPDATE Roommate_Requests r1
JOIN Roommate_Requests r2 ON (
    (r1.requester_id = r2.requested_id AND r1.requested_id = r2.requester_id)
    OR (r1.requester_id = r2.requester_id AND r1.requested_id = r2.requested_id)
)
SET r1.pair_id = r2.pair_id,
    r1.roommate_type = r2.roommate_type
WHERE r1.pair_id IS NULL 
  AND r2.pair_id IS NOT NULL
  AND r1.id != r2.id;

-- 6. 관리자 배정된 룸메이트 설정 (필요시)
-- UPDATE Roommate_Requests 
-- SET roommate_type = 'assigned'
-- WHERE admin_memo LIKE '%관리자 배정%' 
--   AND roommate_type IS NULL;

-- 결과 확인
SELECT 
    status,
    roommate_type,
    COUNT(*) as count
FROM Roommate_Requests 
GROUP BY status, roommate_type
ORDER BY status, roommate_type; 