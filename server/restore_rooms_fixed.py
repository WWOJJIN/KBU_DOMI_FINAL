#!/usr/bin/env python3
import pymysql
import sys

def restore_room_structure():
    """
    기숙사 방 구조 복원
    - 숭례원: 남자 기숙사
    - 양덕원: 여자 기숙사
    - 6층: 1인실 (601-646호)
    - 7층: 2인실 (701-746호)  
    - 8층: 3인실 (801-828호)
    - 9층: 룸메이트 신청자용 (901-920호)
    - 10층: 방학이용 (1001-1020호)
    """
    
    try:
        connection = pymysql.connect(
            host='175.106.96.149',
            user='admin',
            password='tkfkdgo1!',
            database='KBU_DOMI',
            charset='utf8mb4'
        )
        
        cursor = connection.cursor()
        
        # 기존 Room_Info 데이터 백업 (혹시 남은 중요한 데이터가 있을 수 있음)
        print("=== 기존 Room_Info 데이터 백업 ===")
        cursor.execute("SELECT * FROM Room_Info")
        existing_rooms = cursor.fetchall()
        print(f"기존 방 데이터: {len(existing_rooms)}개")
        
        # Room_Info 테이블 초기화
        print("=== Room_Info 테이블 초기화 ===")
        cursor.execute("DELETE FROM Room_Info")
        
        # 방 데이터 생성
        rooms_to_create = []
        
        # 숭례원 (남자 기숙사)
        building = "숭례원"
        
        # 6층: 1인실 (601-646호)
        for room_num in range(601, 647):
            rooms_to_create.append((building, f"{room_num}호", "1인실", 1, 0, "사용가능", 6))
        
        # 7층: 2인실 (701-746호)
        for room_num in range(701, 747):
            rooms_to_create.append((building, f"{room_num}호", "2인실", 2, 0, "사용가능", 7))
        
        # 8층: 3인실 (801-828호)
        for room_num in range(801, 829):
            rooms_to_create.append((building, f"{room_num}호", "3인실", 3, 0, "사용가능", 8))
        
        # 9층: 룸메이트 신청자용 (901-920호)
        for room_num in range(901, 921):
            rooms_to_create.append((building, f"{room_num}호", "룸메이트", 2, 0, "사용가능", 9))
        
        # 10층: 방학이용 (1001-1020호)
        for room_num in range(1001, 1021):
            rooms_to_create.append((building, f"{room_num}호", "방학이용", 1, 0, "사용가능", 10))
        
        # 양덕원 (여자 기숙사)
        building = "양덕원"
        
        # 6층: 1인실 (601-646호)
        for room_num in range(601, 647):
            rooms_to_create.append((building, f"{room_num}호", "1인실", 1, 0, "사용가능", 6))
        
        # 7층: 2인실 (701-746호)
        for room_num in range(701, 747):
            rooms_to_create.append((building, f"{room_num}호", "2인실", 2, 0, "사용가능", 7))
        
        # 8층: 3인실 (801-828호)
        for room_num in range(801, 829):
            rooms_to_create.append((building, f"{room_num}호", "3인실", 3, 0, "사용가능", 8))
        
        # 9층: 룸메이트 신청자용 (901-920호)
        for room_num in range(901, 921):
            rooms_to_create.append((building, f"{room_num}호", "룸메이트", 2, 0, "사용가능", 9))
        
        # 10층: 방학이용 (1001-1020호)
        for room_num in range(1001, 1021):
            rooms_to_create.append((building, f"{room_num}호", "방학이용", 1, 0, "사용가능", 10))
        
        # 방 데이터 삽입
        print(f"=== {len(rooms_to_create)}개 방 데이터 생성 중 ===")
        
        insert_query = """
        INSERT INTO Room_Info (building, room_number, room_type, max_occupancy, current_occupancy, status, floor_number)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        
        cursor.executemany(insert_query, rooms_to_create)
        
        # 결과 확인
        cursor.execute("SELECT building, COUNT(*) FROM Room_Info GROUP BY building")
        results = cursor.fetchall()
        
        print("=== 방 생성 완료 ===")
        for building, count in results:
            print(f"{building}: {count}개 방")
        
        # 층별 통계
        print("\n=== 층별 방 통계 ===")
        cursor.execute("""
            SELECT building, 
                   CASE 
                       WHEN floor_number = 6 THEN '6층(1인실)'
                       WHEN floor_number = 7 THEN '7층(2인실)'
                       WHEN floor_number = 8 THEN '8층(3인실)'
                       WHEN floor_number = 9 THEN '9층(룸메이트)'
                       WHEN floor_number = 10 THEN '10층(방학이용)'
                   END as floor_type,
                   COUNT(*) as count
            FROM Room_Info 
            GROUP BY building, floor_number
            ORDER BY building, floor_number
        """)
        
        floor_stats = cursor.fetchall()
        for building, floor_type, count in floor_stats:
            print(f"{building} {floor_type}: {count}개")
        
        connection.commit()
        print("\n✅ 방 구조 복원 완료!")
        
        # 현재 배정된 학생들 확인
        print("\n=== 현재 배정된 학생 확인 ===")
        cursor.execute("""
            SELECT ds.student_id, ds.name, ds.gender, ds.room_num, ds.dorm_building
            FROM Domi_Students ds
            WHERE ds.room_num IS NOT NULL AND ds.room_num != ''
            ORDER BY ds.dorm_building, ds.room_num
        """)
        
        assigned_students = cursor.fetchall()
        if assigned_students:
            print(f"배정된 학생: {len(assigned_students)}명")
            for student in assigned_students:
                print(f"- {student[1]} ({student[0]}): {student[4]} {student[3]}호 ({student[2]})")
        else:
            print("현재 배정된 학생이 없습니다.")
        
    except Exception as e:
        print(f"오류 발생: {e}")
        if 'connection' in locals():
            connection.rollback()
        sys.exit(1)
    finally:
        if 'connection' in locals():
            connection.close()

if __name__ == "__main__":
    restore_room_structure() 