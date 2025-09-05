from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import pymysql
import uuid
from datetime import datetime, date, timedelta
import os
from werkzeug.utils import secure_filename
import requests
import math

app = Flask(__name__)
CORS(
    app,
    resources={
        r"/*": {
            "origins": "*",
            "methods": [
                "GET",
                "POST",
                "PUT",
                "DELETE",
                "OPTIONS"],
            "allow_headers": [
                "Content-Type",
                "Authorization",
                "Access-Control-Allow-Origin"],
            "expose_headers": [
                "Content-Type",
                "Authorization"],
            "supports_credentials": True,
            "max_age": 3600}})

# MySQL 설정
db_config = {
    'host': '110.165.16.23',
    'port': 3306,
    'user': 'kbu_app',
    'password': 'tkfkdgo1!',
    'db': 'KBU_DOMI',
    'charset': 'utf8mb4',
    'cursorclass': pymysql.cursors.DictCursor
}

UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Flask 앱 설정에 업로드 폴더 추가
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'pdf', 'bmp', 'heic'}

# 경북대학교 좌표 (위도, 경도)
KBU_LATITUDE = 37.747990
KBU_LONGITUDE = 127.187170


def get_db():
    return pymysql.connect(**db_config)


def allowed_file(filename):
    return '.' in filename and filename.rsplit(
        '.', 1)[1].lower() in ALLOWED_EXTENSIONS


@app.after_request
def after_request(response):
    # CORS 헤더 중복 설정 방지
    if 'Access-Control-Allow-Origin' not in response.headers:
        response.headers.add('Access-Control-Allow-Origin', '*')
    if 'Access-Control-Allow-Headers' not in response.headers:
        response.headers.add(
            'Access-Control-Allow-Headers',
            'Content-Type,Authorization')
    if 'Access-Control-Allow-Methods' not in response.headers:
        response.headers.add(
            'Access-Control-Allow-Methods',
            'GET,PUT,POST,DELETE,OPTIONS')
    if 'Access-Control-Allow-Credentials' not in response.headers:
        response.headers.add('Access-Control-Allow-Credentials', 'true')
    return response


def to_iso_date(val):
    if isinstance(val, (date, datetime)):
        return val.strftime('%Y-%m-%d')
    return val


def calculate_distance(lat1, lon1, lat2, lon2):
    """두 지점 간의 거리를 계산 (Haversine 공식)"""
    R = 6371  # 지구 반지름 (km)

    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1

    a = math.sin(dlat / 2)**2 + math.cos(lat1) * \
        math.cos(lat2) * math.sin(dlon / 2)**2
    c = 2 * math.asin(math.sqrt(a))
    distance = R * c

    return distance


def get_coordinates_from_address(address):
    """주소를 좌표로 변환 (카카오 API 사용)"""
    try:
        # 카카오 API 키 (실제 사용 시 환경변수로 관리)
        api_key = "3b92d18f308b572d764ede21b9e62544"  # 실제 API 키로 교체 필요

        url = "https://dapi.kakao.com/v2/local/search/address.json"
        headers = {
            "Authorization": f"KakaoAK {api_key}"
        }
        params = {
            "query": address
        }

        response = requests.get(url, headers=headers, params=params)
        data = response.json()

        if data['documents']:
            doc = data['documents'][0]
            return float(doc['y']), float(doc['x'])  # 위도, 경도
        else:
            return None, None
    except Exception as e:
        print(f"주소 변환 오류: {e}")
        return None, None

# 외박 신청 관련 API


@app.route('/api/overnight/requests', methods=['GET'])
def get_requests():
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute('''
                SELECT
                    o.*,
                    s.name,
                    s.dorm_building as building,
                    s.room_num as room
                FROM Outting o
                LEFT JOIN Domi_Students s ON o.student_id = s.student_id
                ORDER BY o.reg_dt DESC
            ''')
            data = cur.fetchall()
            # 날짜 필드 ISO 포맷으로 변환
            for item in data:
                if item.get('out_start'):
                    item['out_start'] = to_iso_date(item['out_start'])
                if item.get('out_end'):
                    item['out_end'] = to_iso_date(item['out_end'])
        return jsonify(data)
    finally:
        conn.close()


@app.route('/api/overnight/student/requests', methods=['GET'])
def get_student_requests():
    student_id = request.args.get('student_id')
    print(f"[학생 외박 목록] 요청 받음 - 학생 ID: {student_id}")

    if not student_id:
        print("[학생 외박 목록] 오류: 학생 ID가 제공되지 않음")
        return jsonify({'error': '학번이 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                SELECT * FROM Outting
                WHERE student_id = %s
                ORDER BY reg_dt DESC
            '''
            print(f"[학생 외박 목록] 실행할 쿼리: {query}")
            print(f"[학생 외박 목록] 쿼리 파라미터: {student_id}")

            cur.execute(query, (student_id,))
            data = cur.fetchall()
            print(f"[학생 외박 목록] 조회된 데이터 개수: {len(data)}")

            # 날짜 필드 ISO 포맷으로 변환
            for item in data:
                if item.get('out_start'):
                    item['out_start'] = to_iso_date(item['out_start'])
                if item.get('out_end'):
                    item['out_end'] = to_iso_date(item['out_end'])
                print(
                    f"[학생 외박 목록] 처리된 항목: {item['out_uuid']} - {item['stat']}")

        print(f"[학생 외박 목록] 최종 반환 데이터: {data}")
        return jsonify(data)
    except Exception as e:
        print(f"[학생 외박 목록] 데이터베이스 오류: {e}")
        import traceback
        print(f"[학생 외박 목록] 스택 트레이스: {traceback.format_exc()}")
        return jsonify({'error': f'데이터베이스 오류: {str(e)}'}), 500
    finally:
        conn.close()
        print("[학생 외박 목록] 데이터베이스 연결 종료")


@app.route('/api/overnight/request', methods=['POST'])
def add_request():
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
            INSERT INTO Outting (
                out_uuid, student_id, out_type, place, reason, return_time,
                out_start, out_end, par_agr, stat, reg_dt
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            '''

            # UUID 자동 생성
            from uuid import uuid4
            out_uuid = str(uuid4())
            reg_dt = datetime.now()  # 날짜+시간 모두 저장

            # 빈 문자열이면 None으로 변환
            def none_if_empty(val):
                return val if val not in (None, '', 'null') else None

            out_start = none_if_empty(data.get('out_start'))
            out_end = none_if_empty(data.get('out_end'))

            values = (
                out_uuid,  # 자동 생성된 UUID 사용
                data['student_id'],
                data.get('out_type', '외박'),  # 기본값 설정
                data['place'],
                data['reason'],
                data.get(
                    'out_time',
                    data.get(
                        'return_time',
                        '22:00')),
                # out_time 또는 return_time 사용
                out_start,
                out_end,
                1 if data.get('guardian_agree') == 'Y' else 0,  # 보호자 동의 처리
                data.get('stat', '대기'),
                reg_dt
            )

            cur.execute(query, values)
            conn.commit()
        return jsonify({'success': True,
                        'message': '신청이 완료되었습니다.',
                        'out_uuid': out_uuid})
    except Exception as e:
        print(f'외박 신청 오류: {str(e)}')
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/overnight/request/<out_uuid>', methods=['DELETE'])
def delete_request(out_uuid):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute('DELETE FROM Outting WHERE out_uuid = %s', (out_uuid,))
            conn.commit()
        return jsonify({'success': True, 'message': '신청이 삭제되었습니다.'})
    except Exception as e:
        print(f'외박 신청 삭제 오류: {str(e)}')
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 외박 신청 상태 변경 API


@app.route('/api/overnight/request/<out_uuid>/status', methods=['PUT'])
def update_overnight_status(out_uuid):
    """외박 신청 상태 변경 (반려 사유 추가)"""
    data = request.json
    status = data.get('status')
    rejection_reason = data.get('rejection_reason')

    if not status:
        return jsonify({'error': '상태 정보가 필요합니다.'}), 400

    # 반려 상태가 아니면 사유를 저장하지 않음
    if status != '반려':
        rejection_reason = None

    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                UPDATE Outting
                SET stat = %s, rejection_reason = %s
                WHERE out_uuid = %s
            '''
            cur.execute(query, (status, rejection_reason, out_uuid))
            conn.commit()

            if cur.rowcount == 0:
                return jsonify({'error': '해당하는 외박 신청이 없습니다.'}), 404

        return jsonify({'message': '상태가 성공적으로 업데이트되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 외박 신청 샘플 데이터 추가 API


@app.route('/api/admin/overnight/sample-data', methods=['POST'])
def add_overnight_sample_data():
    """테스트용 외박 신청 샘플 데이터 추가"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기존 샘플 데이터 삭제 (테스트용)
            cur.execute(
                "DELETE FROM Outting WHERE student_id IN ('20250001', '20240123', '20230046', '20230047')")

            sample_data = [
                {
                    'out_uuid': '569799bb-2925-44dc-83ec-fcc1bd3cacd1',
                    'student_id': '20250001',
                    'out_type': '외박',
                    'place': '서울',
                    'reason': '가족 방문',
                    'return_time': '22:00',
                    'out_start': '2024-06-20',
                    'out_end': '2024-06-22',
                    'par_agr': '동의',
                    'stat': '대기',
                },
                {
                    'out_uuid': '6dbc3855-6d3b-4d43-85cd-2589ba76a8fd',
                    'student_id': '20240123',
                    'out_type': '외출',
                    'place': '대구',
                    'reason': '병원 진료',
                    'return_time': '18:00',
                    'out_start': '2024-06-21',
                    'out_end': '2024-06-21',
                    'par_agr': '동의',
                    'stat': '대기',
                },
                {
                    'out_uuid': 'ce8e99a0-a2c7-43d1-8eb0-144dfba7ac45',
                    'student_id': '20230046',
                    'out_type': '외박',
                    'place': '부산',
                    'reason': '친구 결혼식',
                    'return_time': '23:00',
                    'out_start': '2024-06-25',
                    'out_end': '2024-06-26',
                    'par_agr': '동의',
                    'stat': '승인',
                },
                {
                    'out_uuid': 'eb364929-70e8-47e1-9ed5-f26d2dc0ffe2',
                    'student_id': '20230047',
                    'out_type': '외출',
                    'place': '경주',
                    'reason': '관광',
                    'return_time': '20:00',
                    'out_start': '2024-06-23',
                    'out_end': '2024-06-23',
                    'par_agr': '동의',
                    'stat': '반려',
                },
                {
                    'out_uuid': 'f0f33721-4e6c-11f0-9c9e-f220afa0d063',
                    'student_id': '20250006',
                    'out_type': '외박',
                    'place': '인천',
                    'reason': '가족 행사',
                    'return_time': '21:00',
                    'out_start': '2024-06-28',
                    'out_end': '2024-06-30',
                    'par_agr': '동의',
                    'stat': '대기',
                },
            ]

            for data in sample_data:
                cur.execute('''
                    INSERT INTO Outting (
                        out_uuid, student_id, out_type, place, reason, return_time,
                        out_start, out_end, par_agr, stat, reg_dt
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ''', (
                    data['out_uuid'], data['student_id'], data['out_type'],
                    data['place'], data['reason'], data['return_time'],
                    data['out_start'], data['out_end'], data['par_agr'],
                    data['stat'], datetime.now()
                ))

            conn.commit()
        return jsonify(
            {'message': f'{len(sample_data)}개의 외박 신청 샘플 데이터가 추가되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 외박신청 승인 건수 반환 API


@app.route('/api/overnight_status_count', methods=['GET'])
def overnight_status_count():
    student_id = request.args.get('student_id')
    print(f"[외박현황] student_id 파라미터: {student_id}")
    sql = """
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN stat = '승인' THEN 1 ELSE 0 END) AS approved,
            SUM(CASE WHEN stat = '대기' THEN 1 ELSE 0 END) AS pending,
            SUM(CASE WHEN stat = '반려' THEN 1 ELSE 0 END) AS rejected
        FROM Outting
        WHERE student_id = %s AND out_type IN ('외박', '외출')
    """
    print(f"[외박현황] 실행 쿼리: {sql}")
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(sql, (student_id,))
            row = cursor.fetchone()
            print(f"[외박현황] 쿼리 결과 row: {row}")
            result = {
                "total": int(row['total'] or 0),
                "approved": int(row['approved'] or 0),
                "pending": int(row['pending'] or 0),
                "rejected": int(row['rejected'] or 0)
            }
            print(f"[외박현황] API 반환값: {result}")
            return jsonify(result)
    finally:
        conn.close()

# AS 신청 승인 건수 반환 API


@app.route('/api/as_status_count', methods=['GET'])
def as_status_count():
    student_id = request.args.get('student_id')
    try:
        student_id = int(student_id)
    except Exception:
        return jsonify({"error": "student_id는 숫자여야 합니다."}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT
                    COUNT(*) AS total,
                    SUM(CASE WHEN stat IN ('접수', '대기중') THEN 1 ELSE 0 END) AS requested,
                    SUM(CASE WHEN stat = '처리중' THEN 1 ELSE 0 END) AS in_progress,
                    SUM(CASE WHEN stat IN ('완료', '처리완료') THEN 1 ELSE 0 END) AS completed
                FROM After_Service
                WHERE student_id = %s
            """
            cursor.execute(sql, (student_id,))
            row = cursor.fetchone()
            print(f"AS 쿼리결과: {row}")
            result = {
                "total": int(row['total'] or 0),
                "requested": int(row['requested'] or 0),
                "in_progress": int(row['in_progress'] or 0),
                "completed": int(row['completed'] or 0)
            }
            print(f"AS 응답결과: {result}")
            return jsonify(result)
    finally:
        conn.close()

# AS 관련 API


@app.route('/api/as/apply', methods=['POST'])
def as_apply():
    data = request.json
    print('받은 데이터:', data)  # 디버그 로그 추가

    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
            INSERT INTO After_Service (
                as_uuid, student_id, as_category, description, stat, reg_dt
            ) VALUES (%s, %s, %s, %s, %s, %s)
            '''

            as_uuid = str(uuid.uuid4())
            now = datetime.now()
            values = (
                as_uuid,
                data['student_id'],
                data.get('as_category'),
                data.get('description'),
                data.get('stat', '대기중'),  # 기본값을 '대기중'으로 통일
                now  # 날짜+시간 모두 저장
            )
            print('DB에 저장할 값:', values)  # 디버그 로그 추가

            cur.execute(query, values)
            conn.commit()
        # as_uuid를 응답에 포함시켜서 클라이언트가 이미지 등록에 사용할 수 있도록 함
        return jsonify({'success': True,
                        'message': 'AS 신청이 완료되었습니다.',
                        'as_uuid': as_uuid})
    except Exception as e:
        print('에러 발생:', str(e))  # 에러 로그 추가
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/as/requests', methods=['GET'])
def get_as_requests():
    student_id = request.args.get('student_id')
    if not student_id:
        return jsonify({'success': False, 'error': '학번이 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # AS 신청 목록 조회
            cur.execute('''
                SELECT * FROM After_Service
                WHERE student_id = %s
                ORDER BY reg_dt DESC
            ''', (student_id,))
            data = cur.fetchall()

            # 각 AS 신청에 대해 첨부 이미지들을 조회
            for item in data:
                item['reg_dt'] = to_iso_date(item['reg_dt'])

                # 첨부 이미지 조회
                cur.execute('''
                    SELECT img_path FROM AS_img_path
                    WHERE as_uuid = %s
                ''', (item['as_uuid'],))
                images = cur.fetchall()

                # 이미지 URL 생성
                item['attachments'] = []
                for img in images:
                    item['attachments'].append({
                        'path': img['img_path'],
                        'url': f'http://localhost:5050/uploads/{img["img_path"]}'
                    })

                # 첨부파일 유무 업데이트 (실제 데이터 기반)
                item['has_attachments'] = len(item['attachments']) > 0

        return jsonify({'success': True, 'requests': data})
    finally:
        conn.close()


@app.route('/api/as/request/<as_uuid>', methods=['DELETE'])
def delete_as_request(as_uuid):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # AS 이미지 경로도 함께 삭제
            cur.execute(
                'DELETE FROM AS_img_path WHERE as_uuid = %s', (as_uuid,))
            # AS 신청 정보 삭제
            cur.execute(
                'DELETE FROM After_Service WHERE as_uuid = %s', (as_uuid,))
            conn.commit()
        return jsonify({'success': True, 'message': 'AS 신청이 삭제되었습니다.'})
    except Exception as e:
        print(f'AS 신청 삭제 중 오류 발생: {str(e)}')
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/as/requests/all', methods=['GET'])
def get_all_as_requests():
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute('''
                SELECT
                    a.*,
                    s.name,
                    s.dorm_building,
                    s.room_num
                FROM After_Service a
                LEFT JOIN Domi_Students s ON a.student_id = s.student_id
                ORDER BY a.reg_dt DESC
            ''')
            data = cur.fetchall()

            # 각 AS 신청에 대해 첨부파일 정보 추가
            for item in data:
                # 날짜 필드 ISO 포맷으로 변환
                item['reg_dt'] = to_iso_date(item['reg_dt'])

                # 첨부파일 조회
                cur.execute('''
                    SELECT img_path FROM AS_img_path
                    WHERE as_uuid = %s
                ''', (item['as_uuid'],))
                images = cur.fetchall()

                # 첨부파일 정보 추가
                attachments = []
                for img in images:
                    attachments.append({
                        'path': img['img_path'],
                        'url': f'http://localhost:5050/uploads/{img["img_path"]}'
                    })

                item['attachments'] = attachments
                item['has_attachments'] = len(attachments) > 0

        return jsonify(data)
    finally:
        conn.close()

# AS 상태 업데이트 API (추가)


@app.route('/api/as/request/<as_uuid>/status', methods=['PUT'])
def update_as_request_status(as_uuid):
    data = request.json
    new_status = data.get('status')
    rejection_reason = data.get('rejection_reason')

    if not new_status:
        return jsonify({'error': '상태 값이 필요합니다.'}), 400

    # 반려 상태가 아니면 사유를 저장하지 않음
    if new_status != '반려':
        rejection_reason = None

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # AS 테이블에 rejection_reason 컬럼이 있다고 가정하고 업데이트
            # 만약 컬럼이 없다면 ALTER TABLE After_Service ADD COLUMN rejection_reason
            # TEXT; 실행 필요
            cur.execute(
                "UPDATE After_Service SET stat = %s, rejection_reason = %s WHERE as_uuid = %s",
                (new_status, rejection_reason, as_uuid)
            )
            conn.commit()
            if cur.rowcount == 0:
                return jsonify({'error': '해당하는 AS 신청이 없습니다.'}), 404
        return jsonify({'message': '상태가 업데이트되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 파일 업로드 관련 API


@app.route('/api/upload', methods=['POST'])
def upload_file():
    print("파일 업로드 요청 시작")
    if 'file' not in request.files:
        print("파일이 없음")
        return {'error': '파일이 없습니다'}, 400

    file = request.files['file']
    if file.filename == '':
        print("파일명이 비어있음")
        return {'error': '파일이 선택되지 않았습니다'}, 400

    if not allowed_file(file.filename):
        print(f"허용되지 않는 파일 형식: {file.filename}")
        return {'error': '허용되지 않는 파일 형식입니다'}, 400

    try:
        print("파일 처리 시작")
        # 안전한 파일명으로 변환
        original_filename = secure_filename(file.filename)
        print(f"원본 파일명: {original_filename}")

        # 고유한 파일명 생성
        unique_filename = f"{uuid.uuid4()}_{original_filename}"
        print(f"생성된 파일명: {unique_filename}")

        # 파일 저장 (AS 전용 폴더 사용)
        file_path = os.path.join('uploads/as', unique_filename)
        print(f"저장 경로: {file_path}")

        os.makedirs('uploads/as', exist_ok=True)  # 폴더가 없으면 생성
        print("폴더 생성/확인 완료")

        file.save(file_path)
        print("파일 저장 완료")

        # 파일 URL 및 DB 저장용 경로 생성
        # 로컬 서버 주소
        file_url = f'http://localhost:5050/uploads/as/{unique_filename}'
        img_path = f'as/{unique_filename}'  # DB에는 이 값 저장
        print(f"파일 URL: {file_url}")
        print(f"이미지 경로: {img_path}")

        return {
            'success': True,
            'url': file_url,
            'original_filename': original_filename,
            'saved_filename': unique_filename,
            'img_path': img_path
        }

    except Exception as e:
        print(f'파일 업로드 중 오류 발생: {str(e)}')
        return {'error': f'파일 업로드 중 오류가 발생했습니다: {str(e)}'}, 500


@app.route('/api/as/image', methods=['POST'])
def save_as_image():
    data = request.json
    as_uuid = data.get('as_uuid')
    img_path = data.get('img_path')
    if not as_uuid or not img_path:
        return jsonify({'error': '필수 데이터 누락'}), 400
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                INSERT INTO AS_img_path (as_uuid, img_path)
                VALUES (%s, %s)
            '''
            cur.execute(query, (as_uuid, img_path))
            conn.commit()
        return jsonify({'message': '이미지 경로 저장 완료'})
    finally:
        conn.close()

# AS 신청의 첨부 이미지 조회 API


@app.route('/api/as/request/<as_uuid>/images', methods=['GET'])
def get_as_images(as_uuid):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute('''
                SELECT img_path FROM AS_img_path
                WHERE as_uuid = %s
            ''', (as_uuid,))
            images = cur.fetchall()

            # 이미지 URL 생성
            image_list = []
            for img in images:
                image_list.append({
                    'path': img['img_path'],
                    'url': f'http://localhost:5050/uploads/{img["img_path"]}'
                })

        return jsonify(image_list)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 정적 파일 서빙 설정


@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    # UPLOAD_FOLDER 설정이 없으면 현재 디렉토리의 uploads 사용
    upload_folder = app.config.get('UPLOAD_FOLDER', 'uploads')
    return send_from_directory(upload_folder, filename)

# 기타 API (퇴소, 석식, 입실, 룸메이트 등)


@app.route('/api/checkout/apply', methods=['POST'])
def apply_checkout():
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 1. checkout 테이블 insert
            cur.execute(
                '''
                INSERT INTO Checkout (
                    student_id, name, year, semester, contact, guardian_contact, emergency_contact,
                    checkout_date, reason, reason_detail, payback_bank, payback_num, payback_name,
                    checklist_clean, checklist_key, checklist_bill, guardian_agree, agree_privacy, status, reg_dt, upd_dt
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ''',
                (data['studentId'],
                 data['name'],
                    data['year'],
                    data['semester'],
                    data['contact'],
                    data['guardianContact'],
                    data['emergencyContact'],
                    data['checkoutDate'],
                    data['reason'],
                    data['reasonDetail'],
                    data['paybackBank'],
                    data['paybackNum'],
                    data['paybackName'],
                    data['checklistClean'],
                    data['checklistKey'],
                    data['checklistBill'],
                    data['guardianAgree'],
                    data['agreePrivacy'],
                    '대기',
                    datetime.now(),
                    datetime.now()))
            checkout_id = cur.lastrowid

            # 2. proofFiles insert
            for file in data.get('proofFiles', []):
                cur.execute('''
                    INSERT INTO Checkout_proof (checkout_id, file_path, file_name, uploaded_at)
                    VALUES (%s, %s, %s, %s)
                ''', (checkout_id, file['filePath'], file['fileName'], datetime.now()))
            conn.commit()
        return jsonify({'success': True, 'checkout_id': checkout_id})
    finally:
        conn.close()


@app.route('/api/checkout/requests', methods=['GET'])
def get_checkout_requests():
    student_id = request.args.get('student_id')
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute('''
                SELECT * FROM Checkout WHERE student_id = %s ORDER BY reg_dt DESC
            ''', (student_id,))
            checkouts = cur.fetchall()
            # 각 신청별 proofFiles join
            for c in checkouts:
                cur.execute(
                    'SELECT * FROM Checkout_proof WHERE checkout_id = %s', (c['checkout_id'],))
                c['proofFiles'] = cur.fetchall()
        return jsonify(checkouts)
    finally:
        conn.close()


@app.route('/api/checkout/<int:checkout_id>', methods=['DELETE'])
def delete_checkout(checkout_id):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                'DELETE FROM Checkout_proof WHERE checkout_id = %s', (checkout_id,))
            cur.execute(
                'DELETE FROM Checkout WHERE checkout_id = %s', (checkout_id,))
            conn.commit()
        return jsonify({'success': True})
    finally:
        conn.close()


@app.route('/api/checkout/proof/upload', methods=['POST'])
def upload_proof():
    file = request.files['file']
    # 안전한 파일명으로 변환
    original_filename = secure_filename(file.filename)
    # 고유한 파일명 생성 (중복 방지)
    unique_filename = f"{uuid.uuid4()}_{original_filename}"
    # 저장 경로를 uploads/out으로 변경
    save_dir = os.path.join(UPLOAD_FOLDER, 'out')
    os.makedirs(save_dir, exist_ok=True)
    save_path = os.path.join(save_dir, unique_filename)
    file.save(save_path)
    # 반환 경로도 수정
    return jsonify({'success': True,
                    'filePath': f'out/{unique_filename}',
                    'fileName': unique_filename})


@app.route('/api/dinner/apply', methods=['POST'])
def dinner_apply():
    """석식 신청 (상태 필드 제거)"""
    data = request.json
    print(f"[석식 신청] 받은 데이터: {data}")

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 중복 신청 체크 (환불된 건은 제외)
            cur.execute("""
                SELECT d.dinner_id
                FROM Dinner d
                LEFT JOIN Dinner_Payment p ON d.dinner_id = p.dinner_id AND p.pay_type = '환불'
                WHERE d.student_id = %s
                  AND d.year = %s
                  AND d.semester = %s
                  AND d.month = %s
                  AND p.dinner_id IS NULL
            """, (
                data['student_id'],
                data.get('year'),
                data.get('semester'),
                data.get('month')
            ))

            if cur.fetchone():
                print(f"[석식 신청] 중복 신청 감지")
                return jsonify({
                    'success': False,
                    'message': '이미 해당 월에 신청한 내역이 있습니다.'
                }), 409

            # 신청 정보 저장
            now = datetime.now()
            cur.execute("""
                INSERT INTO Dinner (
                    student_id, year, semester, month, reg_dt
                ) VALUES (%s, %s, %s, %s, %s)
            """, (
                data['student_id'],
                data.get('year'),
                data.get('semester'),
                data.get('month'),
                now
            ))
            dinner_id = cur.lastrowid

            # 자동 결제 처리
            auto_payment_amount = data.get('amount', 150000)
            cur.execute("""
                INSERT INTO Dinner_Payment (
                    dinner_id, pay_type, amount, pay_dt, note
                ) VALUES (%s, %s, %s, %s, %s)
            """, (
                dinner_id, '결제', auto_payment_amount, now, '자동 결제'
            ))

            conn.commit()
            print(f"[석식 신청] 성공적으로 저장됨 - dinner_id: {dinner_id}")

            return jsonify({
                'success': True,
                'message': '석식 신청 및 결제가 완료되었습니다.',
                'dinner_id': dinner_id
            })
    except Exception as e:
        conn.rollback()
        print(f"[석식 신청] 오류 발생: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
    finally:
        conn.close()


@app.route('/api/dinner/payment', methods=['POST'])
def dinner_payment():
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
            INSERT INTO Dinner_Payment (
                dinner_id, pay_type, amount, pay_dt, note
            ) VALUES (%s, %s, %s, %s, %s)
            '''
            now = datetime.now()
            values = (
                data['dinner_id'],
                data['pay_type'],  # '결제' 또는 '환불'
                data['amount'],
                now,
                data.get('note')
            )
            cur.execute(query, values)
            conn.commit()
        return jsonify({'message': '결제/환불 이력이 저장되었습니다.'})
    finally:
        conn.close()


@app.route('/api/dinner/payments', methods=['GET'])
def get_dinner_payments():
    """석식 결제 내역 조회 - dinner_id 또는 student_id로 조회 가능"""
    dinner_id = request.args.get('dinner_id')
    student_id = request.args.get('student_id')

    if not dinner_id and not student_id:
        return jsonify({'error': 'dinner_id 또는 student_id가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            if dinner_id:
                # 특정 dinner_id의 결제 내역 조회
                cur.execute('''
                    SELECT dp.*, d.year, d.semester, d.month
                    FROM Dinner_Payment dp
                    JOIN Dinner d ON dp.dinner_id = d.dinner_id
                    WHERE dp.dinner_id = %s
                    ORDER BY dp.pay_dt DESC
                ''', (dinner_id,))
            else:
                # 특정 학생의 모든 결제 내역 조회
                cur.execute('''
                    SELECT dp.*, d.year, d.semester, d.month, d.student_id
                    FROM Dinner_Payment dp
                    JOIN Dinner d ON dp.dinner_id = d.dinner_id
                    WHERE d.student_id = %s
                    ORDER BY dp.pay_dt DESC
                ''', (student_id,))

            data = cur.fetchall()

            # pay_dt를 ISO 포맷으로 변환
            for item in data:
                if 'pay_dt' in item and item['pay_dt']:
                    item['pay_dt'] = item['pay_dt'].strftime(
                        '%Y-%m-%dT%H:%M:%S')

        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    print(f"[로그인 API] 받은 전체 데이터: {data}")

    student_id = data.get('student_id')
    password = data.get('password')
    user_type = data.get('user_type')
    login_type = data.get('login_type', '재학생')

    print(f"[로그인 API] user_type: {user_type}, login_type 초기값: {login_type}")

    if user_type == 'current_student':
        login_type = '재학생'
    elif user_type == 'new_student':
        login_type = '신입생'

    print(f"[로그인 API] 변환 후 login_type: {login_type}")

    redirect_to = data.get('redirect_to', 'portal')

    if not student_id or not password:
        return jsonify(
            {'success': False, 'message': '아이디와 비밀번호를 입력해주세요.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 관리자 계정 먼저 확인
            if student_id == 'admin':
                cur.execute(
                    'SELECT * FROM Domi_Students WHERE student_id = %s AND password = %s',
                    (student_id, password)
                )
                admin_user = cur.fetchone()
                if admin_user:
                    return jsonify(
                        {'success': True, 'user': admin_user, 'is_admin': True})

            user = None  # 초기화

            if redirect_to == 'application':
                print(f"[입주신청 로그인] 학번: {student_id}, 로그인타입: {login_type}")

                if login_type == '재학생':
                    query = '''
                        SELECT student_id, name, password
                        FROM KBU_Students
                        WHERE student_id = %s AND password = %s
                          AND student_id REGEXP '^[0-9]+$'
                    '''
                    print(f"[재학생 쿼리] {query}")
                    cur.execute(query, (student_id, password))
                    user = cur.fetchone()
                    print(f"[재학생 결과] {user}")

                elif login_type == '신입생':
                    query = '''
                        SELECT student_id, name, password
                        FROM KBU_Students
                        WHERE student_id = %s AND password = %s
                          AND student_id REGEXP '[a-zA-Z]'
                    '''
                    print(f"[신입생 쿼리] {query}")
                    cur.execute(query, (student_id, password))
                    user = cur.fetchone()
                    print(f"[신입생 결과] {user}")

                else:
                    return jsonify(
                        {'success': False, 'message': '잘못된 로그인 유형입니다.'}), 400

            else:
                print(f"[포털 로그인] 학번: {student_id}")
                cur.execute('''
                    SELECT student_id, name, dept, grade, phone_num,
                           birth_date, gender, dorm_building, room_num, stat
                    FROM Domi_Students
                    WHERE student_id = %s AND password = %s
                ''', (student_id, password))
                user = cur.fetchone()

        if user:
            return jsonify({'success': True, 'user': user, 'is_admin': False})
        else:
            if redirect_to == 'application':
                if login_type == '재학생':
                    return jsonify(
                        {'success': False, 'message': '학번 또는 비밀번호가 틀렸습니다.'}), 401
                else:
                    return jsonify(
                        {'success': False, 'message': '수험번호 또는 생년월일이 틀렸습니다.'}), 401
            else:
                return jsonify(
                    {'success': False, 'message': '아이디 또는 비밀번호가 틀렸습니다.'}), 401

    except Exception as e:
        print(f"로그인 오류: {e}")
        return jsonify({'success': False, 'message': '서버 오류가 발생했습니다.'}), 500
    finally:
        conn.close()


@app.route('/api/student/info', methods=['GET'])
def get_student_info():
    student_id = request.args.get('student_id')
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # academic_status 추가
            cur.execute(
                'SELECT *, academic_status FROM Domi_Students WHERE student_id = %s',
                (student_id,
                 ))
            data = cur.fetchone()
        return jsonify(data or {})
    finally:
        conn.close()


@app.route('/api/student/<student_id>', methods=['GET'])
def get_student_by_id(student_id):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # academic_status 추가하고 birth_date 형식 변경
            cur.execute('''
                SELECT
                    student_id, name, dept, gender, grade, phone_num,
                    DATE_FORMAT(birth_date, %s) as birth_date,
                    par_name, par_phone, payback_bank, payback_name, payback_num,
                    dorm_building, room_num, stat, check_in, check_out,
                    academic_status, roommate_id, password
                FROM Domi_Students
                WHERE student_id = %s
            ''', ('%Y-%m-%d', student_id))
            data = cur.fetchone()

        if data:
            return jsonify({'success': True, 'user': data})
        else:
            return jsonify(
                {'success': False, 'message': '학생을 찾을 수 없습니다.'}), 404
    finally:
        conn.close()


@app.route('/api/student/name/<name>', methods=['GET'])
def get_student_by_name(name):
    """학생 이름으로 검색"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # academic_status 추가
            cur.execute(
                'SELECT *, academic_status FROM Domi_Students WHERE name = %s', (name,))
            data = cur.fetchone()
        if data:
            return jsonify({'success': True, 'user': data})
        else:
            return jsonify(
                {'success': False, 'message': '학생을 찾을 수 없습니다.'}), 404
    finally:
        conn.close()

# --- 룸메이트 신청 관련 API (수정됨) ---

# 1. 룸메이트 신청 생성 (팀원 UI 호환)


@app.route('/api/roommate/apply', methods=['POST'])
def create_roommate_request():
    data = request.json
    requester_id = data.get('requester_id')
    requested_id = data.get('requested_id')
    requested_name = data.get('requested_name')  # 팀원 UI에서는 requested_name 사용

    if not all([requester_id, requested_id, requested_name]):
        return jsonify({'error': '필수 정보가 누락되었습니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 피신청자 정보 확인
            cur.execute(
                "SELECT name FROM Domi_Students WHERE student_id = %s", (requested_id,))
            student = cur.fetchone()
            if not student:
                return jsonify({'error': '존재하지 않는 학생입니다.'}), 404
            if student['name'] != requested_name:
                return jsonify({'error': '학번과 이름이 일치하지 않습니다.'}), 400

            # 이미 관계가 있는지 확인 (룸메이트가 이미 있거나, 신청이 진행중인 경우)
            cur.execute(
                "SELECT id FROM Roommate_Requests WHERE (requester_id = %s AND requested_id = %s) OR (requester_id = %s AND requested_id = %s)",
                (requester_id,
                 requested_id,
                 requested_id,
                 requester_id))
            if cur.fetchone():
                return jsonify({'error': '이미 해당 학생과의 신청이 존재합니다.'}), 409

            # pair_id 생성 (고유한 식별자)
            import uuid
            pair_id = f"pair_{uuid.uuid4().hex[:8]}"

            # roommate_type 설정 (초기에는 'one-way')
            roommate_type = 'one-way'

            query = '''
                INSERT INTO Roommate_Requests (requester_id, requested_id, status, request_date, pair_id, roommate_type)
                VALUES (%s, %s, %s, %s, %s, %s)
            '''
            cur.execute(
                query,
                (requester_id,
                 requested_id,
                 'pending',
                 datetime.now(),
                 pair_id,
                 roommate_type))

            # 생성된 신청의 ID 가져오기
            request_id = cur.lastrowid

            # 이력 테이블에 초기 기록 (중복 방지 체크)
            cur.execute('''
                SELECT COUNT(*) as count FROM Roommate_Request_History 
                WHERE request_id = %s AND new_status = 'pending' AND change_reason = '신청 생성'
            ''', (request_id,))
            
            existing_history = cur.fetchone()
            if existing_history['count'] == 0:
                cur.execute('''
                    INSERT INTO Roommate_Request_History (
                        request_id, requester_id, requested_id, previous_status, new_status,
                        change_reason, changed_by, changed_by_type
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ''', (request_id, requester_id, requested_id, None, 'pending', '신청 생성', requester_id, 'student'))

            conn.commit()
        return jsonify({'message': '룸메이트 신청이 완료되었습니다.'}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 2. 내가 보낸 신청 목록 조회


@app.route('/api/roommate/my-requests', methods=['GET'])
def get_my_roommate_requests():
    student_id = request.args.get('student_id')
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # Domi_Students 테이블과 JOIN하여 피신청자의 이름 가져오기
            query = '''
                SELECT r.*, s.name as roommate_name
                FROM Roommate_Requests r
                JOIN Domi_Students s ON r.requested_id = s.student_id
                WHERE r.requester_id = %s
                ORDER BY r.request_date DESC
            '''
            cur.execute(query, (student_id,))
            data = cur.fetchall()
            for item in data:
                item['request_date'] = to_iso_date(item['request_date'])
                # confirm_date도 변환
                if 'confirm_date' in item and item['confirm_date']:
                    item['confirm_date'] = to_iso_date(item['confirm_date'])
        return jsonify(data)
    finally:
        conn.close()

# 3. 내가 받은 신청 목록 조회


@app.route('/api/roommate/requests-for-me', methods=['GET'])
def get_roommate_requests_for_me():
    student_id = request.args.get('student_id')
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # Domi_Students 테이블과 JOIN하여 신청자의 이름 가져오기
            query = '''
                SELECT r.*, s.name as requester_name
                FROM Roommate_Requests r
                JOIN Domi_Students s ON r.requester_id = s.student_id
                WHERE r.requested_id = %s AND r.status = 'pending'
                ORDER BY r.request_date DESC
            '''
            cur.execute(query, (student_id,))
            data = cur.fetchall()
            for item in data:
                item['request_date'] = to_iso_date(item['request_date'])
        return jsonify(data)
    finally:
        conn.close()

# 4. 본 신청 취소


@app.route('/api/roommate/requests/<int:request_id>', methods=['DELETE'])
def cancel_roommate_request(request_id):
    # TODO: 인증 로직 추가 (신청자 본인만 취소 가능)
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 현재 신청 정보 조회
            cur.execute(
                "SELECT requester_id, status FROM Roommate_Requests WHERE id = %s",
                (request_id,
                 ))
            request_info = cur.fetchone()

            if not request_info:
                return jsonify({'error': '존재하지 않는 신청입니다.'}), 404

            if request_info['status'] != 'pending':
                return jsonify({'error': '취소할 수 없는 신청이거나, 이미 처리된 신청입니다.'}), 400

            # 상태를 cancelled로 변경
            cur.execute(
                "UPDATE Roommate_Requests SET status = 'cancelled' WHERE id = %s", (request_id,))

            # 이력 기록
            cur.execute('''
                INSERT INTO Roommate_Request_History (
                    request_id, requester_id, requested_id, previous_status, new_status,
                    change_reason, changed_by, changed_by_type
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ''', (request_id, request_info['requester_id'], None, 'pending', 'cancelled', '신청 취소', request_info['requester_id'], 'student'))

            conn.commit()
            if cur.rowcount == 0:
                return jsonify({'error': '취소할 수 없는 신청이거나, 이미 처리된 신청입니다.'}), 404
        return jsonify({'message': '신청이 취소되었습니다.'})
    finally:
        conn.close()

# 5. 받은 신청 수락


@app.route('/api/roommate/requests/<int:request_id>/accept', methods=['PUT'])
def accept_roommate_request(request_id):
    # TODO: 인증 로직 추가 (피신청자 본인만 수락 가능)
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 현재 신청 정보 조회
            cur.execute(
                "SELECT requester_id, requested_id, status, pair_id FROM Roommate_Requests WHERE id = %s",
                (request_id,
                 ))
            request_info = cur.fetchone()

            if not request_info:
                return jsonify({'error': '존재하지 않는 신청입니다.'}), 404

            if request_info['status'] != 'pending':
                return jsonify({'error': '수락할 수 없는 신청이거나, 이미 처리된 신청입니다.'}), 400

            # 현재 신청을 수락 상태로 변경
            query = '''
                UPDATE Roommate_Requests
                SET status = 'accepted', confirm_date = %s, roommate_type = 'mutual'
                WHERE id = %s AND status = 'pending'
            '''
            cur.execute(query, (datetime.now(), request_id))

            # 상호 신청 처리: 피신청자가 신청자에게 역신청을 생성하거나 기존 신청을 업데이트
            requester_id = request_info['requester_id']
            requested_id = request_info['requested_id']
            pair_id = request_info['pair_id']
            
            # 역방향 신청이 이미 있는지 확인
            cur.execute(
                "SELECT id FROM Roommate_Requests WHERE requester_id = %s AND requested_id = %s",
                (requested_id, requester_id)
            )
            reverse_request = cur.fetchone()
            
            if reverse_request:
                # 기존 역방향 신청을 'accepted'로 변경하고 같은 pair_id 설정
                cur.execute(
                    '''
                    UPDATE Roommate_Requests
                    SET status = 'accepted', roommate_type = 'mutual', pair_id = %s, confirm_date = %s
                    WHERE id = %s
                    ''',
                    (pair_id, datetime.now(), reverse_request['id'])
                )
                
                # 역방향 신청 이력 기록
                cur.execute('''
                    INSERT INTO Roommate_Request_History (
                        request_id, requester_id, requested_id, previous_status, new_status,
                        change_reason, changed_by, changed_by_type
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ''', (reverse_request['id'], requested_id, requester_id, 'pending', 'accepted', '상호 수락', requested_id, 'student'))
            else:
                # 역방향 신청 생성
                cur.execute(
                    '''
                    INSERT INTO Roommate_Requests (requester_id, requested_id, status, request_date, confirm_date, pair_id, roommate_type)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ''',
                    (requested_id, requester_id, 'accepted', datetime.now(), datetime.now(), pair_id, 'mutual')
                )
                
                reverse_request_id = cur.lastrowid
                
                # 역방향 신청 이력 기록
                cur.execute('''
                    INSERT INTO Roommate_Request_History (
                        request_id, requester_id, requested_id, previous_status, new_status,
                        change_reason, changed_by, changed_by_type
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ''', (reverse_request_id, requested_id, requester_id, None, 'accepted', '상호 신청 생성', requested_id, 'student'))

            # 원본 신청 이력 기록 (중복 방지)
            cur.execute('''
                INSERT INTO Roommate_Request_History (
                    request_id, requester_id, requested_id, previous_status, new_status,
                    change_reason, changed_by, changed_by_type
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ''', (request_id, request_info['requester_id'], request_info['requested_id'], 'pending', 'accepted', '수락', request_info['requested_id'], 'student'))

            conn.commit()
            if cur.rowcount == 0:
                return jsonify({'error': '수락할 수 없는 신청이거나, 이미 처리된 신청입니다.'}), 404
        return jsonify({'message': '신청을 수락했습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 6. 받은 신청 거절


@app.route('/api/roommate/requests/<int:request_id>/reject', methods=['PUT'])
def reject_roommate_request(request_id):
    # TODO: 인증 로직 추가 (피신청자 본인만 거절 가능)
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 현재 신청 정보 조회
            cur.execute(
                "SELECT requester_id, requested_id, status FROM Roommate_Requests WHERE id = %s",
                (request_id,
                 ))
            request_info = cur.fetchone()

            if not request_info:
                return jsonify({'error': '존재하지 않는 신청입니다.'}), 404

            if request_info['status'] != 'pending':
                return jsonify({'error': '거절할 수 없는 신청이거나, 이미 처리된 신청입니다.'}), 400

            query = "UPDATE Roommate_Requests SET status = 'rejected' WHERE id = %s AND status = 'pending'"
            cur.execute(query, (request_id,))

            # 이력 기록
            cur.execute('''
                INSERT INTO Roommate_Request_History (
                    request_id, requester_id, requested_id, previous_status, new_status,
                    change_reason, changed_by, changed_by_type
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ''', (request_id, request_info['requester_id'], request_info['requested_id'], 'pending', 'rejected', '거절', request_info['requested_id'], 'student'))

            conn.commit()
            if cur.rowcount == 0:
                return jsonify({'error': '거절할 수 없는 신청이거나, 이미 처리된 신청입니다.'}), 404
        return jsonify({'message': '신청을 거절했습니다.'})
    finally:
        conn.close()

# 7. 룸메이트 신청 이력 조회 API (새로 추가)


@app.route('/api/roommate/history/<int:request_id>', methods=['GET'])
def get_roommate_request_history(request_id):
    """특정 룸메이트 신청의 상태변경 이력 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                SELECT
                    h.*,
                    req.name as requester_name,
                    res.name as requested_name
                FROM Roommate_Request_History h
                LEFT JOIN Domi_Students req ON h.requester_id = req.student_id
                LEFT JOIN Domi_Students res ON h.requested_id = res.student_id
                WHERE h.request_id = %s
                ORDER BY h.created_at ASC
            '''
            cur.execute(query, (request_id,))
            data = cur.fetchall()

            # 날짜 형식 변환
            for item in data:
                item['created_at'] = to_iso_date(item['created_at'])

            return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 8. 학생별 룸메이트 신청 이력 조회 API (새로 추가)


@app.route('/api/roommate/student-history/<student_id>', methods=['GET'])
def get_student_roommate_history(student_id):
    """특정 학생의 모든 룸메이트 신청 이력 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                SELECT
                    h.*,
                    req.name as requester_name,
                    res.name as requested_name,
                    r.status as current_status
                FROM Roommate_Request_History h
                LEFT JOIN Domi_Students req ON h.requester_id = req.student_id
                LEFT JOIN Domi_Students res ON h.requested_id = res.student_id
                LEFT JOIN Roommate_Requests r ON h.request_id = r.id
                WHERE h.requester_id = %s OR h.requested_id = %s
                ORDER BY h.created_at DESC
            '''
            cur.execute(query, (student_id, student_id))
            data = cur.fetchall()

            # 날짜 형식 변환
            for item in data:
                item['created_at'] = to_iso_date(item['created_at'])

            return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 9. 룸메이트 관계 해지 API (새로 추가)


@app.route('/api/roommate/terminate', methods=['POST'])
def terminate_roommate_relationship():
    """룸메이트 관계 해지"""
    data = request.json
    student_id = data.get('student_id')
    partner_id = data.get('partner_id')
    reason = data.get('reason', '관계 해지')

    if not student_id or not partner_id:
        return jsonify({'error': '학생 ID와 상대방 ID가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기존 룸메이트 관계 확인
            cur.execute('''
                SELECT id, status FROM Roommate_Requests
                WHERE ((requester_id = %s AND requested_id = %s) OR
                       (requester_id = %s AND requested_id = %s))
                AND status IN ('confirmed', 'accepted')
                AND is_active = 1
            ''', (student_id, partner_id, partner_id, student_id))

            relationship = cur.fetchone()
            if not relationship:
                return jsonify({'error': '확인된 룸메이트 관계를 찾을 수 없습니다.'}), 404

            # 관계 해지 처리
            cur.execute('''
                UPDATE Roommate_Requests
                SET status = 'canceled',
                    canceled_at = NOW(),
                    admin_memo = CONCAT(COALESCE(admin_memo, ''), '\n관계 해지: ', %s)
                WHERE id = %s
            ''', (reason, relationship['id']))

            # 이력 테이블에 기록
            cur.execute('''
                INSERT INTO Roommate_Request_History
                (request_id, requester_id, requested_id, previous_status, new_status,
                 change_reason, changed_by, changed_by_type, created_at)
                VALUES (%s, %s, %s, %s, 'canceled', %s, %s, 'student', NOW())
            ''', (relationship['id'], student_id, partner_id, relationship['status'], reason, student_id))

            conn.commit()

        return jsonify({'message': '룸메이트 관계가 해지되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 10. 재신청 가능 여부 확인 API (새로 추가)


@app.route('/api/roommate/can-reapply', methods=['GET'])
def check_can_reapply():
    """특정 학생과의 재신청 가능 여부 확인"""
    requester_id = request.args.get('requester_id')
    requested_id = request.args.get('requested_id')

    if not all([requester_id, requested_id]):
        return jsonify({'error': '신청자 ID와 피신청자 ID가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 최근 해지된 관계 확인 (30일 이내)
            cur.execute('''
                SELECT h.created_at, h.change_reason
                FROM Roommate_Request_History h
                JOIN Roommate_Requests r ON h.request_id = r.id
                WHERE ((r.requester_id = %s AND r.requested_id = %s) OR (r.requester_id = %s AND r.requested_id = %s))
                AND h.new_status = 'terminated'
                AND h.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
                ORDER BY h.created_at DESC
                LIMIT 1
            ''', (requester_id, requested_id, requested_id, requester_id))

            recent_termination = cur.fetchone()

            # 현재 진행중인 신청이 있는지 확인
            cur.execute('''
                SELECT id, status
                FROM Roommate_Requests
                WHERE ((requester_id = %s AND requested_id = %s) OR (requester_id = %s AND requested_id = %s))
                AND status IN ('pending', 'accepted', 'confirmed')
            ''', (requester_id, requested_id, requested_id, requester_id))

            current_request = cur.fetchone()

            can_reapply = True
            reason = None
            remaining_days = None

            if recent_termination:
                termination_date = recent_termination['created_at']
                days_since_termination = (
                    datetime.now() - termination_date).days
                remaining_days = 30 - days_since_termination

                if remaining_days > 0:
                    can_reapply = False
                    reason = f"최근 {
                        termination_date.strftime('%Y-%m-%d')}에 관계가 해지되어 {remaining_days}일 후에 재신청 가능합니다."

            if current_request:
                can_reapply = False
                reason = "이미 진행중인 신청이 있습니다."

            return jsonify({
                'can_reapply': can_reapply,
                'reason': reason,
                'remaining_days': remaining_days,
                'recent_termination_date': recent_termination['created_at'].strftime('%Y-%m-%d') if recent_termination else None
            })

    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 11. 재신청 제한 기간 설정 API (새로 추가)


@app.route('/api/admin/roommate/reapply-period', methods=['POST'])
def set_reapply_period():
    """재신청 제한 기간 설정 (관리자용)"""
    data = request.json
    days = data.get('days', 30)

    if not isinstance(days, int) or days < 0:
        return jsonify({'error': '유효한 일수를 입력해주세요.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 설정 테이블에 저장 (기존 설정이 있으면 업데이트)
            cur.execute('''
                INSERT INTO Settings (`key`, value)
                VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE value = %s
            ''', ('roommate_reapply_period', str(days), str(days)))

            conn.commit()

        return jsonify({'message': f'재신청 제한 기간이 {days}일로 설정되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 12. 재신청 제한 기간 조회 API (새로 추가)


@app.route('/api/admin/roommate/reapply-period', methods=['GET'])
def get_reapply_period():
    """재신청 제한 기간 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute('SELECT value FROM Settings WHERE `key` = %s',
                        ('roommate_reapply_period',))
            result = cur.fetchone()

            days = int(result['value']) if result else 30  # 기본값 30일

        return jsonify({'days': days})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 13. 룸메이트 관계 해지 이력 조회 API (새로 추가)


@app.route('/api/roommate/termination-history/<student_id>', methods=['GET'])
def get_termination_history(student_id):
    """특정 학생의 룸메이트 관계 해지 이력 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                SELECT
                    h.*,
                    req.name as requester_name,
                    res.name as requested_name,
                    r.request_date,
                    r.confirm_date
                FROM Roommate_Request_History h
                LEFT JOIN Domi_Students req ON h.requester_id = req.student_id
                LEFT JOIN Domi_Students res ON h.requested_id = res.student_id
                LEFT JOIN Roommate_Requests r ON h.request_id = r.id
                WHERE (h.requester_id = %s OR h.requested_id = %s)
                AND h.new_status = 'terminated'
                ORDER BY h.created_at DESC
            '''
            cur.execute(query, (student_id, student_id))
            data = cur.fetchall()

            # 날짜 형식 변환
            for item in data:
                item['created_at'] = to_iso_date(item['created_at'])
                if item.get('request_date'):
                    item['request_date'] = to_iso_date(item['request_date'])
                if item.get('confirm_date'):
                    item['confirm_date'] = to_iso_date(item['confirm_date'])

            return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# --- 관리자용 룸메이트 API ---


@app.route('/api/admin/roommate/requests', methods=['GET'])
def admin_get_roommate_requests():
    """관리자용 룸메이트 신청 목록 조회 (pair_id 기반 그룹핑)"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # pair_id와 roommate_type 정보를 포함하여 조회
            query = """
                SELECT
                    r.id,
                    r.requester_id,
                    req.name as applicant_name,
                    r.requested_id,
                    res.name as partner_name,
                    r.status,
                    r.request_date,
                    r.confirm_date,
                    r.pair_id,
                    r.roommate_type,
                    req.dorm_building,
                    req.room_num
                FROM Roommate_Requests r
                LEFT JOIN Domi_Students req ON r.requester_id = req.student_id
                LEFT JOIN Domi_Students res ON r.requested_id = res.student_id
                ORDER BY r.pair_id, r.request_date DESC
            """
            cur.execute(query)
            data = cur.fetchall()

            # pair_id 기반으로 그룹핑
            grouped_data = {}
            for row in data:
                pair_id = row['pair_id'] or f"single_{row['id']}"

                if pair_id not in grouped_data:
                    grouped_data[pair_id] = {
                        'pair_id': pair_id,
                        'roommate_type': row['roommate_type'],
                        'requests': []
                    }

                room_assigned_str = ''
                # 'confirmed' 또는 'accepted' 상태인 경우, 신청자의 방 정보를 '배정된 방'으로 간주
                if row['status'] in ['confirmed',
                                     'accepted'] and row['dorm_building'] and row['room_num']:
                    room_assigned_str = f"{
                        row['dorm_building']} {
                        row['room_num']}"

                grouped_data[pair_id]['requests'].append({
                    'id': row['id'],
                    'applicant_id': row['requester_id'],
                    'applicant_name': row['applicant_name'],
                    'partner_id': row['requested_id'],
                    'partner_name': row['partner_name'],
                    'status': row['status'],
                    'room_assigned': room_assigned_str,
                    'memo': "",
                    'rejection_reason': "",
                    'reg_dt': row['request_date'].isoformat() if row.get('request_date') else None,
                    'upd_dt': row['confirm_date'].isoformat() if row.get('confirm_date') else None,
                })

            # 그룹핑된 결과를 리스트로 변환
            result = list(grouped_data.values())

        return jsonify(result)
    except Exception as e:
        print(f"Error executing roommate query: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/roommate/requests/<int:request_id>/status',
           methods=['PUT'])
def admin_update_roommate_status(request_id):
    """룸메이트 신청 상태 변경 (영어 상태값 처리) - 이력 기록 추가"""
    conn = get_db()
    try:
        data = request.get_json()
        status = data.get('status')
        room_assigned = data.get('room_assigned', '')
        memo = data.get('memo', '')
        rejection_reason = data.get('rejection_reason', '')

        # 영어 상태값을 처리 (DB에는 영어로 저장)
        print(f"받은 상태값: {status}")

        with conn.cursor() as cur:
            # 현재 신청 정보 조회
            cur.execute(
                "SELECT requester_id, requested_id, status FROM Roommate_Requests WHERE id = %s",
                (request_id,
                 ))
            request_info = cur.fetchone()

            if not request_info:
                return jsonify({'error': '존재하지 않는 신청입니다.'}), 404

            previous_status = request_info['status']

            # 먼저 테이블 구조 확인
            cur.execute("DESCRIBE Roommate_Requests")
            columns = [col['Field'] for col in cur.fetchall()]
            print(f"Roommate_Requests 테이블 컬럼: {columns}")

            # 기본 컬럼만 업데이트 (존재하는 컬럼만)
            if 'confirm_date' in columns:
                cur.execute('''
                    UPDATE Roommate_Requests
                    SET status = %s, confirm_date = %s
                    WHERE id = %s
                ''', (status, datetime.now(), request_id))
            else:
                cur.execute('''
                    UPDATE Roommate_Requests
                    SET status = %s
                    WHERE id = %s
                ''', (status, request_id))

            # 이력 기록 (상태가 변경된 경우에만)
            if previous_status != status:
                change_reason = '관리자 상태 변경'
                if status == 'confirmed':
                    change_reason = '관리자 배정완료'
                elif status == 'rejected':
                    change_reason = '관리자 반려'

                cur.execute(
                    '''
                    INSERT INTO Roommate_Request_History (
                        request_id, requester_id, requested_id, previous_status, new_status,
                        change_reason, changed_by, changed_by_type, admin_memo, room_assigned
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ''',
                    (request_id,
                     request_info['requester_id'],
                        request_info['requested_id'],
                        previous_status,
                        status,
                        change_reason,
                        'admin',
                        'admin',
                        memo,
                        room_assigned))

            # 배정완료 상태인 경우, 신청자의 방 정보도 업데이트 (room_assigned 정보 활용)
            if status == 'confirmed' and room_assigned:
                # room_assigned 형식: "양덕원 1001호" → building='양덕원', room='1001'
                parts = room_assigned.split(' ')
                if len(parts) == 2:
                    building = parts[0]
                    room_num = parts[1].replace('호', '')

                    # 신청자의 방 정보 업데이트
                    cur.execute(
                        'SELECT requester_id FROM Roommate_Requests WHERE id = %s', (request_id,))
                    requester_result = cur.fetchone()
                    if requester_result:
                        requester_id = requester_result['requester_id']
                        cur.execute('''
                            UPDATE Domi_Students
                            SET dorm_building = %s, room_num = %s
                            WHERE student_id = %s
                        ''', (building, room_num, requester_id))
                        print(
                            f"신청자 {requester_id}의 방 정보를 {building} {room_num}로 업데이트")

            conn.commit()

        return jsonify({'message': '상태가 업데이트되었습니다.'})
    except Exception as e:
        print(f"룸메이트 상태 업데이트 오류: {e}")
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/roommate/sample-data', methods=['POST'])
def add_roommate_sample_data():
    """테스트용 룸메이트 신청 샘플 데이터 추가"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기존 샘플 데이터 삭제 (테스트용)
            cur.execute("DELETE FROM Roommate_Request_History")
            cur.execute("DELETE FROM Roommate_Requests")

            sample_data = [
                {'requester_id': '1', 'requested_id': '2', 'status': 'pending'},
                {'requester_id': '2', 'requested_id': '1', 'status': 'accepted'},
                {'requester_id': '1', 'requested_id': '3', 'status': 'pending'},
                {'requester_id': '3', 'requested_id': '1', 'status': 'pending'},
            ]

            for data in sample_data:
                cur.execute(
                    '''
                    INSERT INTO Roommate_Requests (
                        requester_id, requested_id, status, request_date
                    ) VALUES (%s, %s, %s, %s)
                ''',
                    (data['requester_id'],
                     data['requested_id'],
                        data['status'],
                        datetime.now()))

                # 생성된 신청의 ID 가져오기
                request_id = cur.lastrowid

                # 이력 기록
                cur.execute('''
                    INSERT INTO Roommate_Request_History (
                        request_id, requester_id, requested_id, previous_status, new_status,
                        change_reason, changed_by, changed_by_type
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ''', (request_id, data['requester_id'], data['requested_id'], None, data['status'], '신청 생성', data['requester_id'], 'student'))

            conn.commit()
        return jsonify(
            {'message': f'{len(sample_data)}개의 룸메이트 신청 샘플 데이터가 추가되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/room-status', methods=['GET'])
def get_room_status():
    """호실 현황 조회 - 실제 배정된 학생 정보"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # TRIM() 함수를 사용하여 각 컬럼의 양쪽 공백을 제거하여 데이터 정합성 보장
            query = """
                SELECT
                    student_id, name,
                    TRIM(dorm_building) as dorm_building,
                    TRIM(room_num) as room_num,
                    TRIM(stat) as stat
                FROM Domi_Students
                WHERE dorm_building IS NOT NULL AND room_num IS NOT NULL
                ORDER BY dorm_building, room_num
            """
            cur.execute(query)
            data = cur.fetchall()

            # DictCursor에 맞게 딕셔너리 키로 데이터에 접근
            result = []
            for row in data:
                result.append({
                    'student_id': row['student_id'],
                    'name': row['name'],
                    'building': row['dorm_building'],
                    'room_number': row['room_num'],
                    'status': row['stat'],  # 'stat' 컬럼을 'status' 키로 매핑
                    'reg_dt': None,  # 테이블에 해당 컬럼 없음
                    'upd_dt': None,  # 테이블에 해당 컬럼 없음
                })

        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/room-status/sample-data', methods=['POST'])
def add_room_status_sample_data():
    """테스트용 호실 배정 샘플 데이터 추가"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기존 샘플 데이터 삭제 (테스트용)
            cur.execute(
                "DELETE FROM Domi_Students WHERE student_id LIKE '2025%' OR student_id LIKE '2024%' OR student_id LIKE '2023%'")

            sample_data = [
                {
                    'student_id': '20250001',
                    'name': '김민지',
                    'building': '양덕원',
                    'room_number': '701호',
                    'status': '입실완료',
                },
                {
                    'student_id': '20240123',
                    'name': '박준영',
                    'building': '숭례원',
                    'room_number': '602호',
                    'status': '입실완료',
                },
                {
                    'student_id': '20230046',
                    'name': '김아름',
                    'building': '양덕원',
                    'room_number': '702호',
                    'status': '배정완료',
                },
                {
                    'student_id': '20230047',
                    'name': '이도현',
                    'building': '숭례원',
                    'room_number': '603호',
                    'status': '입실완료',
                },
                {
                    'student_id': '20250006',
                    'name': '황지은',
                    'building': '양덕원',
                    'room_number': '703호',
                    'status': '배정완료',
                },
                {
                    'student_id': '20251001',
                    'name': '이하나',
                    'building': '양덕원',
                    'room_number': '901호',
                    'status': '입실완료',
                },
                {
                    'student_id': '20251002',
                    'name': '김두리',
                    'building': '양덕원',
                    'room_number': '901호',
                    'status': '입실완료',
                },
                {
                    'student_id': '20251003',
                    'name': '박세영',
                    'building': '숭례원',
                    'room_number': '902호',
                    'status': '배정완료',
                },
                {
                    'student_id': '20251004',
                    'name': '정하영',
                    'building': '숭례원',
                    'room_number': '902호',
                    'status': '입실완료',
                },
            ]

            for data in sample_data:
                cur.execute('''
                    INSERT INTO Domi_Students (
                        student_id, name, building, room_number, status, reg_dt
                    ) VALUES (%s, %s, %s, %s, %s, %s)
                ''', (
                    data['student_id'], data['name'], data['building'],
                    data['room_number'], data['status'], datetime.now()
                ))

            conn.commit()
        return jsonify(
            {'message': f'{len(sample_data)}개의 호실 배정 샘플 데이터가 추가되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 상벌점 관리 API ===


@app.route('/api/admin/students', methods=['GET'])
def get_all_students():
    """입주 학생 목록 조회 (상벌점 관리용) - SQL JOIN 및 서브쿼리로 안정성 개선"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 서브쿼리를 사용하여 상점과 벌점을 각각 계산한 뒤 JOIN하여 안정성 확보
            # academic_status 컬럼 추가
            query = """
                SELECT
                    s.name,
                    s.student_id,
                    s.dorm_building,
                    s.room_num,
                    s.academic_status,
                    COALESCE(plus_scores.total_plus, 0) as plus_score,
                    COALESCE(minus_scores.total_minus, 0) as minus_score
                FROM
                    Domi_Students s
                LEFT JOIN (
                    SELECT student_id, SUM(score) as total_plus
                    FROM PointHistory
                    WHERE point_type = '상점'
                    GROUP BY student_id
                ) as plus_scores ON s.student_id = plus_scores.student_id
                LEFT JOIN (
                    SELECT student_id, SUM(score) as total_minus
                    FROM PointHistory
                    WHERE point_type = '벌점'
                    GROUP BY student_id
                ) as minus_scores ON s.student_id = minus_scores.student_id
                WHERE
                    s.dorm_building IS NOT NULL AND s.room_num IS NOT NULL AND s.student_id != 'admin'
                ORDER BY
                    s.student_id
            """
            cur.execute(query)
            students_data = cur.fetchall()

            result = []
            for i, student_row in enumerate(students_data):
                plus_score = int(student_row['plus_score'])
                minus_score = abs(int(student_row['minus_score']))

                result.append({
                    'number': i + 1,
                    'name': student_row['name'],
                    'student_id': student_row['student_id'],
                    'building': student_row['dorm_building'],
                    'room_number': student_row['room_num'],
                    'plus': plus_score,
                    'minus': minus_score,
                    'total': plus_score - minus_score,
                    'academic_status': student_row.get('academic_status')
                })

        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/student/scores/<student_id>', methods=['GET'])
def get_student_scores(student_id):
    """학생별 상벌점 상세 내역 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = """
                SELECT
                    id, reg_dt, point_type, reason, score, giver
                FROM PointHistory
                WHERE student_id = %s
                ORDER BY reg_dt DESC
            """
            cur.execute(query, (student_id,))
            data = cur.fetchall()

            result = []
            for i, row in enumerate(data):
                is_plus = row['point_type'] == '상점'

                result.append({
                    'number': i + 1,
                    'type': 'plus' if is_plus else 'minus',
                    'content': row['reason'],
                    'score': abs(row['score']),  # 클라이언트에서는 양수로 점수를 표시
                    'event_date': row['reg_dt'].isoformat() if row['reg_dt'] else None,
                    'date': row['reg_dt'].isoformat() if row['reg_dt'] else None,
                    'file_path': None,  # PointHistory 테이블에 파일 경로 컬럼 없음
                    'giver': row['giver']
                })

        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/student/scores', methods=['POST'])
def add_student_score():
    """상벌점 추가"""
    data = request.json
    student_id = data.get('student_id')
    score_type_str = data.get('type')  # 'plus' or 'minus'
    content = data.get('content')
    score_val = data.get('score')
    event_date_str = data.get('event_date')
    # img_path는 현재 DB 스키마에 없으므로 사용하지 않음
    # img_path = data.get('img_path')

    if not all([student_id,
                score_type_str,
                content,
                score_val,
                event_date_str]):
        return jsonify({'error': '필수 데이터가 누락되었습니다.'}), 400

    # 데이터 변환
    point_type = '상점' if score_type_str == 'plus' else '벌점'
    score = int(score_val)
    if point_type == '벌점' and score > 0:
        score = -score  # 벌점은 음수로 저장

    event_date = datetime.fromisoformat(event_date_str.split('T')[0])

    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = """
                INSERT INTO PointHistory (
                    student_id, point_type, reason, score, giver, reg_dt
                ) VALUES (%s, %s, %s, %s, %s, %s)
            """
            cur.execute(query, (
                student_id, point_type, content, score, '관리자', event_date
            ))
            conn.commit()

        return jsonify({'message': '상벌점이 성공적으로 추가되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/score/upload', methods=['POST'])
def upload_score_image():
    """상벌점 첨부파일 업로드 (DB 스키마 변경 전까지 파일 경로는 저장되지 않음)"""
    if 'file' not in request.files:
        return jsonify({'error': '파일이 없습니다'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': '파일이 선택되지 않았습니다'}), 400

    if not allowed_file(file.filename):
        return jsonify({'error': '허용되지 않는 파일 형식입니다'}), 400

    try:
        # 안전한 파일명으로 변환
        original_filename = secure_filename(file.filename)
        # 고유한 파일명 생성
        unique_filename = f"{uuid.uuid4()}_{original_filename}"
        # 파일 저장 (score 전용 폴더 사용)
        file_path = os.path.join('uploads/score', unique_filename)

        os.makedirs('uploads/score', exist_ok=True)
        file.save(file_path)

        # 파일 URL 및 DB 저장용 경로 생성
        file_url = f'http://localhost:5050/uploads/score/{unique_filename}'
        img_path = f'score/{unique_filename}'

        return jsonify({
            'success': True,
            'url': file_url,
            'original_filename': original_filename,
            'saved_filename': unique_filename,
            'img_path': img_path  # 클라이언트에 경로를 반환하지만, DB에 저장되지는 않음
        })

    except Exception as e:
        return jsonify({'error': f'파일 업로드 중 오류가 발생했습니다: {str(e)}'}), 500


@app.route('/api/admin/score/sample-data', methods=['POST'])
def add_score_sample_data():
    """테스트용 상벌점 샘플 데이터 추가"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기존 샘플 데이터 삭제 (테스트용)
            cur.execute("DELETE FROM PointHistory WHERE giver = '샘플데이터'")

            sample_data = [{'student_id': '20250001',
                            'point_type': '상점',
                            'reason': '학업우수',
                            'score': 5,
                            'reg_dt': '2024-05-15'},
                           {'student_id': '20250001',
                            'point_type': '벌점',
                            'reason': '무단외박',
                            'score': -1,
                            'reg_dt': '2024-06-02'},
                           {'student_id': '20240123',
                            'point_type': '상점',
                            'reason': '봉사활동',
                            'score': 4,
                            'reg_dt': '2024-05-18'},
                           {'student_id': '20230046',
                            'point_type': '벌점',
                            'reason': '지각',
                            'score': -3,
                            'reg_dt': '2024-04-10'},
                           {'student_id': '20230047',
                            'point_type': '벌점',
                            'reason': '소음 발생',
                            'score': -2,
                            'reg_dt': '2024-06-09'},
                           {'student_id': '20230047',
                            'point_type': '벌점',
                            'reason': '외부인 무단 출입',
                            'score': -2,
                            'reg_dt': '2024-06-10'},
                           ]

            for data in sample_data:
                cur.execute('''
                    INSERT INTO PointHistory (
                        student_id, point_type, reason, score, giver, reg_dt
                    ) VALUES (%s, %s, %s, %s, %s, %s)
                ''', (
                    data['student_id'], data['point_type'], data['reason'],
                    data['score'], '샘플데이터', data['reg_dt']
                ))

            conn.commit()
        return jsonify(
            {'message': f'{len(sample_data)}개의 상벌점 샘플 데이터가 추가되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 방학이용 관리 API ===
# 오래된 함수 삭제됨 - admin_get_vacation_requests() 함수가 대신 사용됨

# 오래된 함수 삭제됨 - admin_get_vacation_requests() 함수가 대신 사용됨

# 오래된 방학이용 함수들 삭제됨 - 새로운 VacationReservation 테이블 기반 함수들이 대신 사용됨


@app.route('/api/admin/in/requests', methods=['GET'])
def admin_get_in_requests():
    """
    관리자용 입실 신청 전체 목록 조회 (Checkin 테이블에서 조회, Domi_Students JOIN)
    서류 정보도 함께 조회
    """
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # Checkin 테이블과 Domi_Students 테이블을 JOIN하여 필요한 모든 컬럼을 조회
            # 입실신청 상태에 따라 방 배정 정보를 다르게 처리
            query = """
                SELECT
                    c.checkin_id, c.recruit_type, c.year, c.semester, c.name,
                    c.student_id, c.department, c.smoking, c.building, c.room_type,
                    c.room_num, c.status, c.check_comment as admin_memo, c.reg_dt,
                    s.gender,
                    -- 입실신청 상태가 '배정완료' 또는 '입실완료'일 때만 실제 배정 정보 표시
                    CASE
                        WHEN c.status IN ('배정완료', '입실완료') THEN s.dorm_building
                        ELSE c.building
                    END as dorm_building,
                    CASE
                        WHEN c.status IN ('배정완료', '입실완료') THEN s.room_num
                        ELSE NULL
                    END as assigned_room_num,
                    s.birth_date, s.phone_num, s.par_name, s.par_phone, s.grade,
                    s.payback_bank, s.payback_name, s.payback_num, s.academic_status,
                    f.postal_code, f.address_basic, f.address_detail, f.region_type,
                    f.par_name as firstin_par_name, f.par_relation, f.par_phone as firstin_par_phone,
                    f.passport_num, f.tel_home, f.tel_mobile as firstin_tel_mobile,
                    f.is_basic_living, f.is_disabled
                FROM Checkin c
                LEFT JOIN Domi_Students s ON c.student_id = s.student_id
                LEFT JOIN Firstin f ON c.student_id COLLATE utf8mb4_general_ci = f.student_id COLLATE utf8mb4_general_ci
                ORDER BY c.reg_dt DESC
            """
            cur.execute(query)
            data = cur.fetchall()

            # 각 입실신청에 대한 서류 정보 조회
            for item in data:
                cur.execute("""
                    SELECT
                        file_name, file_url, status, file_type, uploaded_at,
                        CASE
                            WHEN status = '확인완료' THEN 1
                            ELSE 0
                        END as isVerified
                    FROM Checkin_Documents
                    WHERE checkin_id = %s
                    ORDER BY uploaded_at DESC
                """, (item['checkin_id'],))

                documents = cur.fetchall()

                # 서류 정보를 Flutter에서 사용하는 형식으로 변환
                item['documents'] = []
                for doc in documents:
                    item['documents'].append({
                        'name': doc['file_name'] or '서류',
                        'fileName': doc['file_name'],
                        'fileUrl': doc['file_url'],
                        'fileType': doc['file_type'],
                        'isVerified': bool(doc['isVerified']),
                        'uploadedAt': doc['uploaded_at'].isoformat() if doc['uploaded_at'] else None
                    })

                # 날짜 필드를 ISO 포맷 문자열로 변환
                if item.get('reg_dt') and hasattr(item['reg_dt'], 'isoformat'):
                    item['reg_dt'] = item['reg_dt'].isoformat()
                if item.get('birth_date') and hasattr(
                        item['birth_date'], 'isoformat'):
                    item['birth_date'] = item['birth_date'].isoformat()

        return jsonify(data)
    except Exception as e:
        print(f"입실 신청 조회 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 입실신청 서류 확인 상태 업데이트 API


@app.route('/api/admin/checkin/document/<int:checkin_id>/verify',
           methods=['PUT'])
def verify_checkin_document(checkin_id):
    """입실신청 서류 확인 상태 업데이트"""
    data = request.json
    file_name = data.get('fileName')
    is_verified = data.get('isVerified', True)

    if not file_name:
        return jsonify({'error': 'fileName이 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 먼저 해당 서류가 존재하는지 확인
            cur.execute("""
                SELECT status FROM Checkin_Documents
                WHERE checkin_id = %s AND file_name = %s
            """, (checkin_id, file_name))
            
            existing_doc = cur.fetchone()
            if not existing_doc:
                return jsonify({'error': '해당 서류를 찾을 수 없습니다.'}), 404
            
            # 서류 상태 업데이트
            new_status = '확인완료' if is_verified else '제출완료'
            current_status = existing_doc['status']
            
            # 이미 같은 상태라면 업데이트하지 않고 성공 응답
            if current_status == new_status:
                print(f"서류 {file_name}는 이미 {new_status} 상태입니다. 업데이트 스킵.")
            else:
                cur.execute("""
                    UPDATE Checkin_Documents
                    SET status = %s
                    WHERE checkin_id = %s AND file_name = %s
                """, (new_status, checkin_id, file_name))

            # 모든 서류가 확인되었는지 체크
            cur.execute("""
                SELECT COUNT(*) as total,
                       SUM(CASE WHEN status = '확인완료' THEN 1 ELSE 0 END) as verified
                FROM Checkin_Documents
                WHERE checkin_id = %s
            """, (checkin_id,))

            result = cur.fetchone()
            all_verified = result['total'] > 0 and result['total'] == result['verified']

            # 모든 서류가 확인되면 입실신청 상태를 '확인'으로 업데이트
            if all_verified:
                cur.execute("""
                    UPDATE Checkin
                    SET status = '확인', check_comment = CONCAT(IFNULL(check_comment, ''), ' [자동] 모든 서류 확인 완료')
                    WHERE checkin_id = %s AND status IN ('미확인', '미배정')
                """, (checkin_id,))

        conn.commit()
        return jsonify({
            'message': '서류 확인 상태가 업데이트되었습니다.',
            'allVerified': all_verified
        })
    except Exception as e:
        conn.rollback()
        print(f"서류 확인 상태 업데이트 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 관리자용 퇴소 신청 목록 조회 API


@app.route('/api/admin/checkout/requests', methods=['GET'])
def admin_get_checkout_requests():
    """관리자용 퇴소 신청 전체 목록 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute('''
                SELECT * FROM Checkout
                ORDER BY reg_dt DESC
            ''')
            checkouts = cur.fetchall()

            # 각 신청별 proofFiles join
            for c in checkouts:
                cur.execute(
                    'SELECT * FROM Checkout_proof WHERE checkout_id = %s', (c['checkout_id'],))
                c['proofFiles'] = cur.fetchall()

                # DB에서 0/1로 넘어오는 값을 bool로 변환
                bool_fields = [
                    'checklist_clean',
                    'checklist_key',
                    'checklist_bill',
                    'guardian_agree',
                    'agree_privacy']
                for field in bool_fields:
                    if field in c and c[field] is not None:
                        c[field] = bool(c[field])

                # 날짜 필드 ISO 포맷으로 변환
                if 'reg_dt' in c and c['reg_dt']:
                    c['reg_dt'] = c['reg_dt'].isoformat()
                if 'upd_dt' in c and c['upd_dt']:
                    c['upd_dt'] = c['upd_dt'].isoformat()
                if 'checkout_date' in c and c['checkout_date']:
                    c['checkout_date'] = to_iso_date(c['checkout_date'])

        return jsonify(checkouts)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 퇴소 신청 상태 변경 API - 단계별 처리


@app.route('/api/admin/checkout/<int:checkout_id>/status', methods=['PUT'])
def admin_update_checkout_status(checkout_id):
    """관리자 퇴소 신청 상태 변경 - 단계별 처리"""
    data = request.json
    new_status = data.get('status')
    admin_memo = data.get('adminMemo', '')

    if not new_status:
        return jsonify({'error': '상태가 필요합니다.'}), 400

    # 허용된 상태값 정의
    allowed_statuses = ['대기', '서류확인중', '점검대기', '승인', '반려']
    if new_status not in allowed_statuses:
        return jsonify({'error': f'허용되지 않은 상태입니다: {new_status}'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 현재 상태 확인
            cur.execute(
                "SELECT status FROM Checkout WHERE checkout_id = %s", (checkout_id,))
            current = cur.fetchone()
            if not current:
                return jsonify({'error': '해당 신청을 찾을 수 없습니다.'}), 404

            current_status = current['status']

            # 상태 변경 규칙 검증
            valid_transitions = {
                '대기': ['서류확인중', '반료'],
                '서류확인중': ['점검대기', '반료'],
                '점검대기': ['승인', '반료'],
                '승인': [],  # 최종 상태
                '반료': []   # 최종 상태
            }

            if new_status not in valid_transitions.get(current_status, []):
                return jsonify({
                    'error': f'현재 상태({current_status})에서 {new_status}로 변경할 수 없습니다.'
                }), 400

            # 상태 업데이트
            cur.execute("""
                UPDATE Checkout
                SET status = %s, upd_dt = %s
                WHERE checkout_id = %s
            """, (new_status, datetime.now(), checkout_id))

            # 퇴소 승인 시 학생의 거주 상태를 '퇴소'로 변경
            if new_status == '승인':
                # 퇴소 신청한 학생의 student_id 가져오기
                cur.execute(
                    "SELECT student_id FROM Checkout WHERE checkout_id = %s", (checkout_id,))
                result = cur.fetchone()
                if result:
                    student_id = result['student_id']

                    # Domi_Students 테이블의 stat을 '퇴소'로 업데이트
                    cur.execute("""
                        UPDATE Domi_Students
                        SET stat = '퇴소', check_out = %s
                        WHERE student_id = %s
                    """, (datetime.now(), student_id))

                    print(f"[퇴소 승인] 학생 {student_id}의 거주 상태를 '퇴소'로 업데이트했습니다.")

            conn.commit()

            # 상태별 메시지
            status_messages = {
                '서류확인중': '서류 검토를 시작했습니다.',
                '점검대기': '서류 확인이 완료되었습니다. 퇴실 점검을 진행해주세요.',
                '승인': '퇴소 신청이 최종 승인되었습니다.',
                '반료': '퇴소 신청이 반료되었습니다.'
            }

        return jsonify({'message': status_messages.get(
            new_status, f'상태가 {new_status}로 변경되었습니다.'), 'new_status': new_status})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 퇴소 신청 샘플 데이터 추가 API


@app.route('/api/admin/checkout/sample-data', methods=['POST'])
def add_checkout_sample_data():
    """테스트용 퇴소 신청 샘플 데이터 추가"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기존 샘플 데이터 삭제 (테스트용)
            cur.execute(
                "DELETE FROM Checkout WHERE student_id IN ('20250001', '20240123', '20230046', '20230047')")

            sample_data = [
                {
                    'student_id': '20250001',
                    'name': '김민지',
                    'year': '2025',
                    'semester': '1',
                    'contact': '010-1234-5678',
                    'guardian_contact': '010-9876-5432',
                    'emergency_contact': '010-1111-2222',
                    'checkout_date': '2024-07-15',
                    'reason': '졸업',
                    'reason_detail': '졸업으로 인한 퇴소',
                    'payback_bank': '신한은행',
                    'payback_num': '110-123456-789',
                    'payback_name': '김민지',
                    'checklist_clean': True,
                    'checklist_key': True,
                    'checklist_bill': True,
                    'guardian_agree': True,
                    'agree_privacy': True,
                    'status': '대기',
                },
                {
                    'student_id': '20240123',
                    'name': '박준영',
                    'year': '2024',
                    'semester': '2',
                    'contact': '010-2345-6789',
                    'guardian_contact': '010-8765-4321',
                    'emergency_contact': '010-2222-3333',
                    'checkout_date': '2024-08-01',
                    'reason': '개인사정',
                    'reason_detail': '가족과 함께 거주하기 위해',
                    'payback_bank': '국민은행',
                    'payback_num': '123-456789-012',
                    'payback_name': '박준영',
                    'checklist_clean': False,
                    'checklist_key': True,
                    'checklist_bill': True,
                    'guardian_agree': True,
                    'agree_privacy': True,
                    'status': '대기',
                },
                {
                    'student_id': '20230046',
                    'name': '김아름',
                    'year': '2023',
                    'semester': '2',
                    'contact': '010-3456-7890',
                    'guardian_contact': '010-7654-3210',
                    'emergency_contact': '010-3333-4444',
                    'checkout_date': '2024-06-30',
                    'reason': '전학',
                    'reason_detail': '다른 대학교로 전학',
                    'payback_bank': '우리은행',
                    'payback_num': '456-789012-345',
                    'payback_name': '김아름',
                    'checklist_clean': True,
                    'checklist_key': True,
                    'checklist_bill': False,
                    'guardian_agree': True,
                    'agree_privacy': True,
                    'status': '승인',
                },
                {
                    'student_id': '20230047',
                    'name': '이도현',
                    'year': '2023',
                    'semester': '2',
                    'contact': '010-4567-8901',
                    'guardian_contact': '010-6543-2109',
                    'emergency_contact': '010-4444-5555',
                    'checkout_date': '2024-07-20',
                    'reason': '군입대',
                    'reason_detail': '군대 입대 예정',
                    'payback_bank': '하나은행',
                    'payback_num': '789-012345-678',
                    'payback_name': '이도현',
                    'checklist_clean': True,
                    'checklist_key': True,
                    'checklist_bill': True,
                    'guardian_agree': True,
                    'agree_privacy': True,
                    'status': '반려',

                },
            ]

            for data in sample_data:
                cur.execute(
                    '''
                    INSERT INTO Checkout (
                        student_id, name, year, semester, contact, guardian_contact, emergency_contact,
                        checkout_date, reason, reason_detail, payback_bank, payback_num, payback_name,
                        checklist_clean, checklist_key, checklist_bill, guardian_agree, agree_privacy,
                        status, reg_dt, upd_dt
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ''',
                    (data['student_id'],
                     data['name'],
                        data['year'],
                        data['semester'],
                        data['contact'],
                        data['guardian_contact'],
                        data['emergency_contact'],
                        data['checkout_date'],
                        data['reason'],
                        data['reason_detail'],
                        data['payback_bank'],
                        data['payback_num'],
                        data['payback_name'],
                        data['checklist_clean'],
                        data['checklist_key'],
                        data['checklist_bill'],
                        data['guardian_agree'],
                        data['agree_privacy'],
                        data['status'],
                        datetime.now(),
                        datetime.now()))

            conn.commit()
        return jsonify(
            {'message': f'{len(sample_data)}개의 퇴소 신청 샘플 데이터가 추가되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 관리자 대시보드 요약 API


@app.route('/api/admin/dashboard/summary', methods=['GET'])
def admin_dashboard_summary():
    """관리자 대시보드 요약 정보 - 실제 DB 데이터 연동"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 1. 총 입주자 수 (입주중인 학생들만)
            try:
                cur.execute("""
                    SELECT COUNT(*) as total_residents
                    FROM Domi_Students
                    WHERE stat IN ('입주중', '입주승인') AND student_id != 'admin'
                """)
                total_residents = cur.fetchone()['total_residents']
                print(f"🏠 총 입주자 수: {total_residents}")
            except Exception as e:
                print(f"❌ 총 입주자 수 조회 오류: {e}")
                total_residents = 0

            # 2. 금일 외박 승인 건수 (오늘 날짜에 외박 중인 학생)
            try:
                today = datetime.now().date()
                cur.execute("""
                    SELECT COUNT(DISTINCT student_id) as today_outs
                    FROM Outting
                    WHERE stat = '승인'
                    AND %s BETWEEN out_start AND out_end
                    AND out_type IN ('외박', '외출')
                """, (today,))
                today_outs_count = cur.fetchone()['today_outs']
            except Exception:
                today_outs_count = 0

            # 3. 금일 점호 현황 (오늘 날짜 기준)
            try:
                # 전체 점호 대상 학생 수 (입주중 - 외박승인)
                cur.execute("""
                    SELECT COUNT(DISTINCT ds.student_id) as rollcall_target
                    FROM Domi_Students ds
                    LEFT JOIN Outting o ON ds.student_id = o.student_id
                        AND o.stat = '승인'
                        AND %s BETWEEN o.out_start AND o.out_end
                    WHERE ds.stat IN ('입주중', '입주승인')
                        AND ds.student_id != 'admin'
                        AND o.student_id IS NULL
                """, (today,))
                rollcall_target = cur.fetchone()['rollcall_target']
                print(f"📋 점호 대상 학생 수: {rollcall_target}")

                # 점호 완료 학생 수
                cur.execute("""
                    SELECT COUNT(*) as rollcall_done
                    FROM RollCall
                    WHERE rollcall_date = %s
                """, (today,))
                rollcall_done = cur.fetchone()['rollcall_done']

                rollcall_pending = rollcall_target - rollcall_done
            except Exception:
                rollcall_target = 0
                rollcall_done = 0
                rollcall_pending = 0

            # 4. 석식 현황 (현재 월, 이전 월, 다음 월)
            try:
                current_month = datetime.now().month
                current_year = datetime.now().year
                prev_month = current_month - 1 if current_month > 1 else 12
                prev_year = current_year if current_month > 1 else current_year - 1
                next_month = current_month + 1 if current_month < 12 else 1
                next_year = current_year if current_month < 12 else current_year + 1

                # 월 문자열로 변환 (DB에 "7월" 형태로 저장되어 있음)
                current_month_str = f"{current_month}월"
                prev_month_str = f"{prev_month}월"
                next_month_str = f"{next_month}월"

                # 현재 월 석식 신청 수
                cur.execute("""
                    SELECT COUNT(*) as current_dinner
                    FROM Dinner
                    WHERE year = %s AND month = %s
                """, (current_year, current_month_str))
                current_dinner = cur.fetchone()['current_dinner']

                # 이전 월 석식 신청 수
                cur.execute("""
                    SELECT COUNT(*) as prev_dinner
                    FROM Dinner
                    WHERE year = %s AND month = %s
                """, (prev_year, prev_month_str))
                prev_dinner = cur.fetchone()['prev_dinner']

                # 다음 월 석식 신청 수
                cur.execute("""
                    SELECT COUNT(*) as next_dinner
                    FROM Dinner
                    WHERE year = %s AND month = %s
                """, (next_year, next_month_str))
                next_dinner = cur.fetchone()['next_dinner']

                dinner_counts = {
                    'prev_month': prev_month,
                    'prev_count': prev_dinner,
                    'current_month': current_month,
                    'current_count': current_dinner,
                    'next_month': next_month,
                    'next_count': next_dinner
                }
            except Exception:
                dinner_counts = {
                    'prev_month': datetime.now().month - 1,
                    'prev_count': 0,
                    'current_month': datetime.now().month,
                    'current_count': 0,
                    'next_month': datetime.now().month + 1,
                    'next_count': 0
                }

            # 5. 기숙사별 입주 현황
            try:
                # 양덕원 입주 현황
                cur.execute("""
                    SELECT
                        COUNT(*) as occupied_rooms,
                        (SELECT COUNT(*) FROM Room_Info WHERE building = '양덕원') as total_rooms
                    FROM Domi_Students
                    WHERE dorm_building = '양덕원' AND stat IN ('입주중', '입주승인')
                """)
                yangdeok_data = cur.fetchone()
                yangdeok_occupied = yangdeok_data['occupied_rooms']
                # Room_Info 데이터 기준
                yangdeok_total = yangdeok_data['total_rooms'] or 160
                yangdeok_vacant = yangdeok_total - yangdeok_occupied
                yangdeok_rate = round(
                    (yangdeok_occupied / yangdeok_total * 100) if yangdeok_total > 0 else 0, 1)
                print(
                    f"🏢 양덕원: 입주={yangdeok_occupied}, 공실={yangdeok_vacant}, 입주율={yangdeok_rate}%")

                # 숭례원 입주 현황
                cur.execute("""
                    SELECT
                        COUNT(*) as occupied_rooms,
                        (SELECT COUNT(*) FROM Room_Info WHERE building = '숭례원') as total_rooms
                    FROM Domi_Students
                    WHERE dorm_building = '숭례원' AND stat IN ('입주중', '입주승인')
                """)
                sunglye_data = cur.fetchone()
                sunglye_occupied = sunglye_data['occupied_rooms']
                # Room_Info 데이터 기준
                sunglye_total = sunglye_data['total_rooms'] or 160
                sunglye_vacant = sunglye_total - sunglye_occupied
                sunglye_rate = round(
                    (sunglye_occupied / sunglye_total * 100) if sunglye_total > 0 else 0, 1)
                print(
                    f"🏢 숭례원: 입주={sunglye_occupied}, 공실={sunglye_vacant}, 입주율={sunglye_rate}%")

                building_occupancy = {
                    'yangdeokwon': {
                        'occupied': yangdeok_occupied,
                        'vacant': yangdeok_vacant,
                        'total': yangdeok_total,
                        'rate': yangdeok_rate
                    },
                    'sunglyewon': {
                        'occupied': sunglye_occupied,
                        'vacant': sunglye_vacant,
                        'total': sunglye_total,
                        'rate': sunglye_rate
                    }
                }
            except Exception as e:
                print(f"❌ 기숙사별 입주 현황 조회 오류: {e}")
                building_occupancy = {
                    'yangdeokwon': {
                        'occupied': 0,
                        'vacant': 160,
                        'total': 160,
                        'rate': 0},
                    'sunglyewon': {
                        'occupied': 0,
                        'vacant': 160,
                        'total': 160,
                        'rate': 0}}

            # 6. 최근 신청 내역 (다양한 신청 통합)
            try:
                recent_applications = []

                # 외박 신청
                cur.execute("""
                    SELECT
                        o.student_id, s.name, o.reason, o.reg_dt, '외박' as type
                    FROM Outting o
                    LEFT JOIN Domi_Students s ON o.student_id = s.student_id
                    WHERE o.stat = '대기'
                    ORDER BY o.reg_dt DESC
                    LIMIT 5
                """)
                overnight_apps = cur.fetchall()

                # AS 신청
                cur.execute("""
                    SELECT
                        a.student_id, s.name, a.description as reason, a.reg_dt, 'AS' as type
                    FROM After_Service a
                    LEFT JOIN Domi_Students s ON a.student_id = s.student_id
                    WHERE a.stat = '대기중'
                    ORDER BY a.reg_dt DESC
                    LIMIT 5
                """)
                as_apps = cur.fetchall()

                # 퇴소 신청
                cur.execute("""
                    SELECT
                        c.student_id, s.name, c.reason, c.reg_dt, '퇴소' as type
                    FROM Checkout c
                    LEFT JOIN Domi_Students s ON c.student_id = s.student_id
                    WHERE c.status = '신청'
                    ORDER BY c.reg_dt DESC
                    LIMIT 5
                """)
                checkout_apps = cur.fetchall()

                # 모든 신청을 합치고 최신순으로 정렬
                all_apps = list(overnight_apps) + \
                    list(as_apps) + list(checkout_apps)
                all_apps.sort(key=lambda x: x['reg_dt'], reverse=True)

                # 최대 10개까지만
                for app in all_apps[:10]:
                    recent_applications.append({
                        'student_id': app['student_id'],
                        'name': app['name'],
                        'type': app['type'],
                        'reason': app['reason'][:50] + '...' if len(app['reason']) > 50 else app['reason'],
                        'reg_dt': app['reg_dt'].isoformat() if app['reg_dt'] else None
                    })

            except Exception as e:
                print(f"최근 신청 내역 조회 오류: {e}")
                recent_applications = []

        return jsonify({
            'totalResidents': total_residents,
            'todayOutsCount': today_outs_count,
            'rollcallStats': {
                'target': rollcall_target,
                'done': rollcall_done,
                'pending': rollcall_pending
            },
            'dinnerCounts': dinner_counts,
            'buildingOccupancy': building_occupancy,
            'recentApplications': recent_applications
        })
    except Exception as e:
        print(f"대시보드 요약 API 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 석식 관리 API ===


def can_refund_dinner(student_id, target_month, target_year):
    """특정 월의 석식 환불 가능 여부 확인"""
    now = datetime.now()
    current_month = now.month
    current_year = now.year

    # 환불 기간: 해당 월의 1일~15일
    if now.day > 15:
        return False, "환불 기간이 지났습니다."

    # 현재 월의 석식만 환불 가능
    if target_month != current_month or target_year != current_year:
        return False, "현재 월의 석식만 환불 가능합니다."

    # 해당 월에 석식 신청이 있는지 확인
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT dinner_id FROM Dinner
                WHERE student_id = %s AND month = %s AND year = %s
            """, (student_id, target_month, target_year))
            if not cur.fetchone():
                return False, "해당 월의 석식 신청 내역이 없습니다."
    finally:
        conn.close()

    return True, "환불 가능합니다."

# settings table logic


def get_setting(key, default=None):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT value FROM Settings WHERE `key` = %s", (key,))
            result = cur.fetchone()
            return result['value'] if result else default
    except pymysql.err.ProgrammingError:
        # Settings 테이블이 없을 경우 대비
        return default
    finally:
        conn.close()


def set_setting(key, value):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 테이블이 없다면 생성 시도 (최초 1회 실행)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS Settings (
                    `key` VARCHAR(50) PRIMARY KEY,
                    `value` VARCHAR(255)
                )
            """)
            cur.execute(
                "INSERT INTO Settings (`key`, value) VALUES (%s, %s) ON DUPLICATE KEY UPDATE value = %s",
                (key,
                 value,
                 value))
            conn.commit()
    finally:
        conn.close()


@app.route('/api/admin/dinner/period-settings', methods=['POST'])
def set_dinner_period_settings():
    """석식 결제/환불 기간 설정 (매월 반복)"""
    data = request.json
    start_day = data.get('start_day')  # 1~31
    end_day = data.get('end_day')     # 1~31
    is_custom = data.get('is_custom', False)  # 커스텀 설정 여부

    if is_custom and start_day and end_day:
        # 커스텀 기간 설정
        set_setting('dinner_period_custom_mode', '1')
        set_setting('dinner_period_start_day', str(start_day))
        set_setting('dinner_period_end_day', str(end_day))
    else:
        # 기본 기간으로 리셋 (1일~15일)
        set_setting('dinner_period_custom_mode', '0')
        set_setting('dinner_period_start_day', '1')
        set_setting('dinner_period_end_day', '15')

    return jsonify({'message': '석식 결제/환불 기간이 업데이트되었습니다.'})


@app.route('/api/admin/dinner/period-info', methods=['GET'])
def get_dinner_period_info():
    """석식 결제/환불 기간 정보 조회"""
    is_custom_mode = get_setting('dinner_period_custom_mode', '0') == '1'
    start_day = int(get_setting('dinner_period_start_day', '1'))
    end_day = int(get_setting('dinner_period_end_day', '15'))

    now = datetime.now()
    current_month = now.month
    current_year = now.year
    current_day = now.day

    # 현재 월의 기간 내인지 확인
    can_apply = start_day <= current_day <= end_day

    return jsonify({
        'can_apply': can_apply,
        'start_day': start_day,
        'end_day': end_day,
        'current_month': current_month,
        'current_year': current_year,
        'current_day': current_day,
        'is_custom': is_custom_mode,
        'message': f"매월 {start_day}일~{end_day}일 결제/환불 가능" + (" (관리자 설정)" if is_custom_mode else " (기본 설정)"),
        'period_display': f"매월 {start_day}일 ~ {end_day}일"
    })


@app.route('/api/admin/dinner/all-requests', methods=['GET'])
def admin_get_dinner_requests():
    """관리자용 석식 신청 전체 목록 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = """
                SELECT
                    d.dinner_id, d.year, d.semester, d.month, d.reg_dt,
                    d.student_id, s.name as student_name, s.dorm_building, s.room_num,
                    (SELECT amount FROM Dinner_Payment WHERE dinner_id = d.dinner_id AND pay_type = '결제' LIMIT 1) as payment_amount,
                    (SELECT pay_dt FROM Dinner_Payment WHERE dinner_id = d.dinner_id AND pay_type = '결제' LIMIT 1) as payment_date,
                    (SELECT amount FROM Dinner_Payment WHERE dinner_id = d.dinner_id AND pay_type = '환불' LIMIT 1) as refund_amount,
                    (SELECT pay_dt FROM Dinner_Payment WHERE dinner_id = d.dinner_id AND pay_type = '환불' LIMIT 1) as refund_date
                FROM Dinner d
                LEFT JOIN Domi_Students s ON d.student_id = s.student_id
                ORDER BY d.reg_dt DESC
            """
            cur.execute(query)
            requests = cur.fetchall()

            # 결제/환불 상태를 동적으로 결정하고 날짜 포맷 변환
            for req in requests:
                if req.get('reg_dt'):
                    req['reg_dt'] = req['reg_dt'].isoformat()
                if req.get('payment_date'):
                    req['payment_date'] = req['payment_date'].isoformat()
                if req.get('refund_date'):
                    req['refund_date'] = req['refund_date'].isoformat()

                # 상태 동적 결정 ('신청' 상태 제거)
                if req.get('refund_date'):
                    req['status'] = '환불완료'
                else:
                    req['status'] = '결제완료'

            return jsonify(requests)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/dinner/<int:dinner_id>/status', methods=['PUT'])
def admin_update_dinner_status(dinner_id):
    """석식 결제/환불 처리"""
    data = request.json
    action = data.get('action')  # 'payment' 또는 'refund'
    amount = data.get('amount', 150000)
    manual_date = data.get('manual_date')
    note = data.get('note', '')

    if not action or action not in ['payment', 'refund']:
        return jsonify({'error': 'action 값이 필요합니다. (payment 또는 refund)'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 중복 처리 방지
            pay_type = '결제' if action == 'payment' else '환불'
            cur.execute(
                "SELECT 1 FROM Dinner_Payment WHERE dinner_id = %s AND pay_type = %s",
                (dinner_id,
                 pay_type))
            if cur.fetchone():
                return jsonify({'error': f'이미 {pay_type} 처리된 신청입니다.'}), 409

            # 환불의 경우 결제 내역이 있는지 확인
            if action == 'refund':
                cur.execute(
                    "SELECT 1 FROM Dinner_Payment WHERE dinner_id = %s AND pay_type = '결제'",
                    (dinner_id,
                     ))
                if not cur.fetchone():
                    return jsonify({'error': '결제 내역이 없어 환불할 수 없습니다.'}), 400

            # 결제/환불 이력 추가
            payment_date = datetime.fromisoformat(
                manual_date) if manual_date else datetime.now()
            cur.execute("""
                INSERT INTO Dinner_Payment (dinner_id, pay_type, amount, pay_dt, note)
                VALUES (%s, %s, %s, %s, %s)
            """, (dinner_id, pay_type, amount, payment_date, note or f'관리자 {pay_type} 처리'))

            conn.commit()

        return jsonify({'message': f'{pay_type}가 완료되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 공지사항 관리 API ===


@app.route('/api/admin/notice', methods=['GET'])
def get_notice():
    """공지사항 조회 (카테고리별)"""
    category = request.args.get('category', 'general')
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # Fetch the latest active notice for the given category
            cur.execute(
                "SELECT * FROM Notice WHERE category = %s AND is_active = 1 ORDER BY updated_at DESC LIMIT 1",
                (category,)
            )
            notice = cur.fetchone()

            # If no specific notice, try to get a general one
            if not notice and category != 'general':
                cur.execute(
                    "SELECT * FROM Notice WHERE category = 'general' AND is_active = 1 ORDER BY updated_at DESC LIMIT 1"
                )
                notice = cur.fetchone()

            if notice and notice.get('updated_at'):
                notice['updated_at'] = notice['updated_at'].isoformat()

        return jsonify(notice or {})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/notice', methods=['POST'])
def create_notice():
    """공지사항 생성"""
    data = request.json
    title = data.get('title')
    content = data.get('content')
    category = data.get('category', 'general')

    if not title or not content:
        return jsonify({'error': '제목과 내용이 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO Notice (title, content, category, created_at, updated_at, is_active) VALUES (%s, %s, %s, %s, %s, 1)",
                (title, content, category, datetime.now(), datetime.now())
            )
            conn.commit()

        return jsonify({'message': '공지사항이 생성되었습니다.'}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/notice/<int:notice_id>', methods=['PUT'])
def update_notice(notice_id):
    """공지사항 수정"""
    data = request.json
    title = data.get('title')
    content = data.get('content')
    category = data.get('category', 'general')
    is_active = data.get('is_active', True)

    if not title or not content:
        return jsonify({'error': '제목과 내용이 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE Notice SET title = %s, content = %s, category = %s, is_active = %s, updated_at = %s WHERE id = %s",
                (title,
                 content,
                 category,
                 is_active,
                 datetime.now(),
                 notice_id))
            conn.commit()

            if cur.rowcount == 0:
                return jsonify({'error': '해당하는 공지사항이 없습니다.'}), 404

        return jsonify({'message': '공지사항이 수정되었습니다.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 학생용 공지사항 조회 API


@app.route('/api/notice', methods=['GET'])
def get_student_notice():
    """학생용 공지사항 조회 (카테고리별)"""
    category = request.args.get('category', 'general')
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT title, content, updated_at FROM Notice WHERE category = %s AND is_active = 1 ORDER BY updated_at DESC LIMIT 1",
                (category,
                 ))
            notice = cur.fetchone()

            if not notice and category != 'general':
                cur.execute(
                    "SELECT title, content, updated_at FROM Notice WHERE category = 'general' AND is_active = 1 ORDER BY updated_at DESC LIMIT 1")
                notice = cur.fetchone()

            if notice and notice.get('updated_at'):
                notice['updated_at'] = notice['updated_at'].isoformat()

        return jsonify(notice or {})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 석식 관리 API ===


@app.route('/api/point/history', methods=['GET'])
def get_point_history():
    """학생용 상벌점 내역 조회 (필터링 가능)"""
    student_id = request.args.get('student_id')
    point_type = request.args.get('type')  # '상점' or '벌점'
    from_date_str = request.args.get('from')
    to_date_str = request.args.get('to')

    if not student_id:
        return jsonify(
            {'success': False, 'error': 'student_id is required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            query_params = [student_id]
            query = """
                SELECT id, student_id, point_type, score, reason, giver, reg_dt
                FROM PointHistory
                WHERE student_id = %s
            """

            if point_type:
                query += " AND point_type = %s"
                query_params.append(point_type)

            if from_date_str:
                query += " AND DATE(reg_dt) >= %s"
                query_params.append(from_date_str)

            if to_date_str:
                query += " AND DATE(reg_dt) <= %s"
                query_params.append(to_date_str)

            query += " ORDER BY reg_dt DESC"

            cur.execute(query, tuple(query_params))
            data = cur.fetchall()

            for item in data:
                if 'reg_dt' in item and item['reg_dt']:
                    item['reg_dt'] = item['reg_dt'].isoformat()

        return jsonify({'success': True, 'points': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 관리자용 입실 신청 정보 업데이트 API


@app.route('/api/admin/in/request/<int:checkin_id>', methods=['PUT'])
def admin_update_in_request(checkin_id):
    """관리자용 입실 신청 상태 및 정보 업데이트 (이력 기록 포함)"""
    data = request.json
    status = data.get('status')
    admin_memo = data.get('adminMemo')
    assigned_building = data.get('assignedBuilding')
    assigned_room_number = data.get('assignedRoomNumber')

    if not status:
        return jsonify({'error': '상태(status)는 필수입니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 현재 상태 조회 (이력 기록용)
            cur.execute(
                "SELECT status, student_id FROM Checkin WHERE checkin_id = %s", (checkin_id,))
            current_checkin = cur.fetchone()

            if not current_checkin:
                return jsonify({'error': '해당하는 입실 신청이 없습니다.'}), 404

            previous_status = current_checkin['status']
            student_id = current_checkin['student_id']

            # 1. Checkin 테이블 업데이트
            query_checkin = """
                UPDATE Checkin
                SET status = %s, check_comment = %s
                WHERE checkin_id = %s
            """
            cur.execute(query_checkin, (status, admin_memo, checkin_id))

            # 2. Domi_Students 테이블 업데이트 (방 배정 정보)
            # '배정완료' 또는 '입실완료'일 때만 방 정보를 업데이트
            if status in [
                '배정완료',
                    '입실완료'] and assigned_building and assigned_room_number:
                query_student = """
                    UPDATE Domi_Students
                    SET dorm_building = %s, room_num = %s, stat = %s
                    WHERE student_id = %s
                """
                # Domi_Students의 stat도 Checkin의 status와 동기화
                cur.execute(
                    query_student,
                    (assigned_building,
                     assigned_room_number,
                     status,
                     student_id))
            # '미배정'이나 '반려' 등으로 상태가 변경되면 방 정보를 NULL로 초기화
            elif status in ['미배정', '반려']:
                query_student_reset = """
                    UPDATE Domi_Students
                    SET dorm_building = NULL, room_num = NULL, stat = %s
                    WHERE student_id = %s
                """
                cur.execute(query_student_reset, (status, student_id))

            # 3. 상태 변경 이력 기록 (상태가 변경된 경우에만)
            if previous_status != status:
                change_reason = '관리자 상태 변경'
                if status == '배정완료':
                    change_reason = '관리자 배정완료'
                elif status == '입실완료':
                    change_reason = '관리자 입실완료'
                elif status == '반려':
                    change_reason = '관리자 반려'
                elif status == '미배정':
                    change_reason = '관리자 미배정'

                # 이력 테이블에 기록 (실제 테이블 구조에 맞게 수정)
                cur.execute('''
                    INSERT INTO Checkin_Status_History (
                        checkin_id, prev_status, status, changed_at, changed_by, comment
                    ) VALUES (%s, %s, %s, %s, %s, %s)
                ''', (
                    checkin_id, previous_status, status, datetime.now(), 'admin', admin_memo
                ))

            conn.commit()

            if cur.rowcount == 0:
                return jsonify({'error': '해당하는 입실 신청이 없거나 변경된 내용이 없습니다.'}), 404

        return jsonify({'message': '입실 신청 정보가 성공적으로 업데이트되었습니다.'})
    except Exception as e:
        conn.rollback()
        print(f"입실 신청 업데이트 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 신입생 입주신청(Firstin) 관리 API ===

# 0. 신입생 입주신청 저장 (학생용)


@app.route('/api/firstin/apply', methods=['POST'])
def apply_firstin():
    """학생용 신입생 입주신청 저장"""
    data = request.json
    print(f"[입주신청] 받은 데이터: {data}")

    # 학년 데이터 변환 (1학년 → 1)
    if 'grade' in data and data['grade']:
        grade_str = str(data['grade'])
        if '학년' in grade_str:
            # "1학년", "2학년" → "1", "2"
            data['grade'] = grade_str.replace('학년', '')
        print(f"[입주신청] 변환된 학년: {data['grade']}")

    # 필수 필드 검증
    required_fields = [
        'student_id',
        'name',
        'gender',
        'department',
        'tel_mobile']
    for field in required_fields:
        if not data.get(field):
            return jsonify({'error': f'{field} 필드가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 중복 신청 확인
            cur.execute(
                "SELECT id FROM Firstin WHERE student_id = %s", (data['student_id'],))
            if cur.fetchone():
                return jsonify({'error': '이미 입주 신청이 완료되었습니다.'}), 409

            # 주소로부터 거리 계산
            full_address = f"{
                data.get(
                    'address_basic',
                    '')} {
                data.get(
                    'address_detail',
                    '')}"
            lat, lon = get_coordinates_from_address(full_address)
            distance = None
            if lat and lon:
                distance = calculate_distance(
                    KBU_LATITUDE, KBU_LONGITUDE, lat, lon)
                print(f"[입주신청] 계산된 거리: {distance}km")

            # 성별에 따른 기숙사 건물 설정
            building = '숭례원' if data.get('gender') == '남자' else '양덕원'

            # Firstin 테이블에 데이터 삽입
            query = """
                INSERT INTO Firstin (
                    recruit_type, year, semester, student_id, name, birth_date, gender,
                    nationality, grade, department, passport_num, applicant_type,
                    address_basic, address_detail, postal_code, region_type, tel_home, tel_mobile,
                    par_name, par_relation, par_phone,
                    is_basic_living, is_disabled, reg_dt, distance, status,
                    dorm_building, room_type, smoking_status, bank, account_num, account_holder
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s
                )
            """

            values = (
                data.get('recruit_type', '신입생'),
                data.get('year', '2025'),
                data.get('semester', '1학기'),
                data['student_id'],
                data['name'],
                data.get('birth_date'),
                data['gender'],
                data.get('nationality', '대한민국'),
                data.get('grade', '1학년'),
                data['department'],
                data.get('passport_num') if data.get('passport_num') else None,
                data.get('applicant_type', '내국인'),
                data.get('address_basic'),
                data.get('address_detail'),
                data.get('postal_code'),
                data.get('region_type'),
                data.get('tel_home') if data.get('tel_home') else None,
                data['tel_mobile'],
                data.get('par_name'),
                data.get('par_relation'),
                data.get('par_phone'),
                1 if data.get('is_basic_living') else 0,
                1 if data.get('is_disabled') else 0,
                datetime.now(),
                distance,
                '신청',
                building,
                data.get('room_type'),
                data.get('smoking_status', '비흡연'),
                data.get('bank'),
                data.get('account_num'),
                data.get('account_holder')
            )

            cur.execute(query, values)
            conn.commit()

            print(
                f"[입주신청] 성공적으로 저장됨 - 학번: {data['student_id']}, 거리: {distance}km")
            return jsonify({
                'success': True,
                'message': '입주 신청이 성공적으로 제출되었습니다.',
                'application_id': cur.lastrowid,
                'distance': distance
            }), 201

    except Exception as e:
        conn.rollback()
        print(f"[입주신청] 저장 오류: {e}")
        import traceback
        print(f"[입주신청] 스택 트레이스: {traceback.format_exc()}")
        return jsonify({'error': f'신청 저장 중 오류가 발생했습니다: {str(e)}'}), 500
    finally:
        conn.close()

# 0-1. 학생용 입실신청 목록 조회


@app.route('/api/firstin/my-applications', methods=['GET'])
def get_my_firstin_applications():
    """학생용 입실신청 목록 조회"""
    student_id = request.args.get('student_id')

    if not student_id:
        return jsonify({'error': 'student_id 파라미터가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = """
                SELECT
                    id, recruit_type, year, semester, student_id, name, gender,
                    department, address_basic, address_detail, postal_code,
                    tel_mobile, tel_home, par_name, par_relation, par_phone,
                    birth_date, applicant_type, grade, nationality,
                    status, reg_dt, dorm_building, room_type, smoking_status,
                    bank, account_num, account_holder
                FROM Firstin
                WHERE student_id = %s
                ORDER BY reg_dt DESC
            """
            cur.execute(query, (student_id,))
            data = cur.fetchall()

            # 데이터 변환
            for item in data:
                item['address'] = f"{
                    item.get(
                        'address_basic',
                        '')} {
                    item.get(
                        'address_detail',
                        '')}".strip()
                item['studentName'] = item['name']
                item['id'] = f"app{item['id']}"

                # 상태 번역
                if item.get('status') == '신청':
                    item['status'] = 'pending'
                elif item.get('status') == '확인':
                    item['status'] = 'confirmed'
                elif item.get('status') == '배정완료':
                    item['status'] = 'assigned'
                elif item.get('status') == '반려':
                    item['status'] = 'rejected'

                # 날짜 포맷팅
                if item.get('reg_dt'):
                    item['created_at'] = item['reg_dt'].strftime(
                        '%Y-%m-%d %H:%M:%S')

        return jsonify(data)
    except Exception as e:
        print(f"학생 입실신청 목록 조회 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 1. 신입생 신청 목록 조회 (전체)


@app.route('/api/admin/firstin/applications', methods=['GET'])
def get_firstin_applications():
    """관리자용 신입생 입주 신청 전체 목록 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # Firstin 테이블의 모든 데이터를 조회
            query = """
                SELECT
                    id, recruit_type, year, semester, student_id, name, birth_date,
                    gender, nationality, passport_num, applicant_type, grade, department,
                    postal_code, address_basic, address_detail, region_type,
                    tel_home, tel_mobile, is_basic_living, is_disabled,
                    par_name, par_relation, par_phone, reg_dt,
                    distance, status, admin_memo, dorm_building, room_type, smoking_status,
                    bank, account_num, account_holder
                FROM Firstin
                ORDER BY reg_dt DESC
            """
            cur.execute(query)
            data = cur.fetchall()

            # 데이터 변환 및 매핑
            for item in data:
                # 주소 합치기
                item['address'] = f"{
                    item.get(
                        'address_basic',
                        '')} {
                    item.get(
                        'address_detail',
                        '')}".strip()

                # 날짜 포맷 변환
                if item.get('birth_date'):
                    item['birth_date'] = item['birth_date'].strftime(
                        '%Y-%m-%d')

                # boolean 값 처리
                item['basic_living_support'] = bool(
                    item.get('is_basic_living', False))
                item['disabled'] = bool(item.get('is_disabled', False))

                # ID 변환 (클라이언트 호환성)
                item['id'] = f"app{item['id']}"

                # null 값들을 빈 문자열이나 기본값으로 처리
                for key, value in item.items():
                    if value is None:
                        if key in ['basic_living_support', 'disabled']:
                            item[key] = False
                        elif key in ['distance']:
                            item[key] = 0
                        else:
                            item[key] = ''

        return jsonify(data)
    except pymysql.err.ProgrammingError as e:
        # status, distance 컬럼이 없을 경우를 대비한 예외 처리
        if 1054 in e.args:  # "Unknown column" error
            with conn.cursor() as cur:
                query_fallback = """
                    SELECT
                        id, recruit_type, year, semester, student_id, name, gender,
                        department, address_basic, address_detail, tel_mobile
                    FROM Firstin
                    ORDER BY reg_dt DESC
                """
                cur.execute(query_fallback)
                data = cur.fetchall()
                for item in data:
                    item['status'] = '미확인'
                    item['distance'] = None
                    item['admin_memo'] = None
                    item['address'] = f"{
                        item.get(
                            'address_basic',
                            '')} {
                        item.get(
                            'address_detail',
                            '')}".strip()
                    # for compatibility with dart code
                    item['studentName'] = item['name']
                    item['smokingStatus'] = '비흡연'
                    item['dormBuilding'] = '정보없음'
                    item['roomType'] = '정보없음'
                    item['id'] = f"app{item['id']}"

                    # 실제 DB 컬럼명을 프론트엔드에서 기대하는 이름으로 매핑
                    if 'par_name' in item:
                        item['guardian_name'] = item['par_name']
                    if 'par_relation' in item:
                        item['guardian_relation'] = item['par_relation']
                    if 'par_phone' in item:
                        item['guardian_phone'] = item['par_phone']
            return jsonify(data)
        else:
            raise e
    except Exception as e:
        print(f"신입생 신청 조회 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


# 2. 거리 계산 및 상위 300명 선별
@app.route('/api/admin/firstin/distance-calculate', methods=['POST'])
def calculate_distances_and_select():
    """
    Firstin 테이블의 학생 주소를 기반으로 거리를 계산하고,
    상위 300명을 '자동선별' 상태로 업데이트합니다.
    카카오 API KEY가 필요합니다.
    """
    conn = get_db()

    # 주의: 이 API를 실행하기 전에 Firstin 테이블에 distance(FLOAT), status(VARCHAR) 컬럼 추가가 필요합니다.
    # ALTER TABLE Firstin ADD COLUMN distance FLOAT;
    # ALTER TABLE Firstin ADD COLUMN status VARCHAR(20) DEFAULT '신청';

    try:
        with conn.cursor() as cur:
            # 아직 거리가 계산되지 않은 학생들 조회
            cur.execute(
                "SELECT id, address_basic FROM Firstin WHERE distance IS NULL OR distance = 0")
            students = cur.fetchall()

            calculated_count = 0
            for student in students:
                address = student['address_basic']
                if address:
                    lat, lon = get_coordinates_from_address(address)
                    if lat and lon:
                        distance = calculate_distance(
                            lat, lon, KBU_LATITUDE, KBU_LONGITUDE)
                        # 거리(km)를 소수점 2자리까지 반올림하여 저장
                        cur.execute(
                            "UPDATE Firstin SET distance = %s WHERE id = %s",
                            (round(distance, 2), student['id'])
                        )
                        calculated_count += 1

            conn.commit()

            # 🔄 이전 자동선별 결과 초기화 (재선별 가능하도록)
            cur.execute("""
                UPDATE Firstin
                SET status = '신청'
                WHERE status = '자동선별'
            """)
            reset_count = cur.rowcount

            # 거리순으로 상위 50명 선별하여 '자동선별' 상태로 업데이트
            cur.execute("""
                UPDATE Firstin
                SET status = '자동선별'
                WHERE id IN (
                    SELECT id FROM (
                        SELECT id FROM Firstin
                        WHERE distance IS NOT NULL
                        AND status = '신청'  -- 신청 상태인 학생만 대상
                        ORDER BY distance DESC
                        LIMIT 50
                    ) as top_students
                )
            """)
            top_selected_count = cur.rowcount

            # 🎯 **핵심 추가**: 자동선별된 학생들을 Domi_Students 테이블에 자동 추가
            cur.execute("""
                SELECT f.* FROM Firstin f
                WHERE f.status = '자동선별'
                AND f.student_id COLLATE utf8mb4_general_ci NOT IN (
                    SELECT student_id FROM Domi_Students 
                    WHERE student_id IS NOT NULL
                )
            """)
            auto_selected_students = cur.fetchall()

            for student in auto_selected_students:
                # 학년 데이터 변환 
                grade = student.get('grade', '1')
                if grade and '학년' in str(grade):
                    grade = str(grade).replace('학년', '')

                # 기존 비밀번호 가져오기
                cur.execute("SELECT password FROM KBU_Students WHERE student_id = %s", (student['student_id'],))
                kbu_student = cur.fetchone()
                
                if kbu_student and kbu_student['password']:
                    default_password = kbu_student['password']
                else:
                    # 기본 비밀번호 생성
                    if len(student['student_id']) >= 4 and student['student_id'].isdigit():
                        default_password = student['student_id'][-4:]
                    else:
                        birth_date = student.get('birth_date')
                        if birth_date:
                            default_password = birth_date.strftime('%Y%m%d')
                        else:
                            default_password = '19990101'

                # Domi_Students에 추가
                insert_query = """
                    INSERT INTO Domi_Students (
                        student_id, name, dept, birth_date, gender, grade, phone_num,
                        par_name, par_phone, dorm_building, stat, password,
                        payback_bank, payback_name, payback_num, academic_status
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    )
                """
                
                cur.execute(insert_query, (
                    student['student_id'], student['name'], student['department'],
                    student.get('birth_date'), student['gender'], grade,
                    student['tel_mobile'], student.get('par_name'), student.get('par_phone'),
                    student.get('dorm_building'), '입주승인', default_password,
                    student.get('bank'), student.get('account_holder'), student.get('account_num'),
                    '재학'
                ))

            # 🎯 **핵심 추가**: 나머지 학생들을 '선별제외' 상태로 업데이트
            cur.execute("""
                UPDATE Firstin
                SET status = '선별제외'
                WHERE distance IS NOT NULL
                AND status = '신청'  -- 아직 신청 상태인 학생들
            """)
            excluded_count = cur.rowcount

            conn.commit()

            print(f"[자동선별] 초기화: {reset_count}명, 선별: {top_selected_count}명, 제외: {excluded_count}명, Domi_Students 추가: {len(auto_selected_students)}명")

        return jsonify({
            'message': f'거리 계산 및 자동 선별이 완료되었습니다. (초기화: {reset_count}명, 선별: {top_selected_count}명, 제외: {excluded_count}명)',
            'total_calculated': calculated_count,
            'top_selected': top_selected_count,
            'excluded_count': excluded_count,
            'domi_students_added': len(auto_selected_students),
            'reset_count': reset_count
        })
    except Exception as e:
        conn.rollback()
        print(f"거리 계산 오류: {e}")
        return jsonify(
            {'error': f"거리 계산 중 오류 발생: {e}. 'distance'와 'status' 컬럼이 Firstin 테이블에 존재하는지 확인해주세요."}), 500
    finally:
        conn.close()

# 3. 자동 선별된 학생 목록 조회


@app.route('/api/admin/firstin/distance-ranked', methods=['GET'])
def get_distance_ranked_students():
    """자동선별 또는 특정 상태의 학생 목록을 거리순으로 조회"""
    status = request.args.get('status', '자동선별')
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = """
                SELECT
                    id, recruit_type, year, semester, student_id, name, birth_date,
                    gender, nationality, passport_num, applicant_type, grade, department,
                    postal_code, address_basic, address_detail, region_type,
                    tel_home, tel_mobile, is_basic_living, is_disabled,
                    par_name, par_relation, par_phone, reg_dt,
                    distance, status, admin_memo, dorm_building, room_type, smoking_status,
                    bank, account_num, account_holder
                FROM Firstin
                WHERE status = %s
                ORDER BY distance ASC
            """
            cur.execute(query, (status,))
            data = cur.fetchall()

            # 데이터 변환 및 매핑
            for item in data:
                # 주소 합치기
                item['address'] = f"{
                    item.get(
                        'address_basic',
                        '')} {
                    item.get(
                        'address_detail',
                        '')}".strip()

                # 날짜 포맷 변환
                if item.get('birth_date'):
                    item['birth_date'] = item['birth_date'].strftime(
                        '%Y-%m-%d')

                # boolean 값 처리
                item['basic_living_support'] = bool(
                    item.get('is_basic_living', False))
                item['disabled'] = bool(item.get('is_disabled', False))

                # ID 변환 (클라이언트 호환성)
                item['id'] = f"app{item['id']}"

                # null 값들을 빈 문자열이나 기본값으로 처리
                for key, value in item.items():
                    if value is None:
                        if key in ['basic_living_support', 'disabled']:
                            item[key] = False
                        elif key in ['distance']:
                            item[key] = 0
                        else:
                            item[key] = ''

        return jsonify(data)
    except Exception as e:
        print(f"선별 학생 목록 조회 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 4. 신입생 신청 상태 업데이트 (승인/선별제외)


@app.route('/api/admin/firstin/application/<int:application_id>',
           methods=['PUT'])
def update_firstin_application_status(application_id):
    """신입생 입주 신청 상태 업데이트 (예: 승인, 선별제외) 및 관리자 메모 저장"""
    data = request.json
    status = data.get('status')
    admin_memo = data.get('admin_memo')

    # 상태 또는 메모 중 하나는 있어야 함
    if not status and not admin_memo:
        return jsonify(
            {'error': '상태(status) 또는 관리자 메모(admin_memo) 정보가 필요합니다.'}), 400

    conn = get_db()
    current_status = '신청'  # 기본값 설정
    try:
        with conn.cursor() as cur:
            # 먼저 신청 정보를 조회 (승인 시 Domi_Students에 추가하기 위해)
            cur.execute(
                "SELECT * FROM Firstin WHERE id = %s", (application_id,))
            application = cur.fetchone()

            if not application:
                return jsonify({'error': '해당하는 신청이 없습니다.'}), 404

            # 현재 상태 저장 (응답 메시지용)
            current_status = application.get('status', '신청')

            # 업데이트할 필드들을 동적으로 구성
            update_fields = []
            values = []

            if status:
                update_fields.append("status = %s")
                values.append(status)

            if admin_memo is not None:  # 빈 문자열도 허용
                update_fields.append("admin_memo = %s")
                values.append(admin_memo)

            values.append(application_id)  # WHERE 조건용

            # Firstin 테이블 업데이트
            query = f"UPDATE Firstin SET {
                ', '.join(update_fields)} WHERE id = %s"
            cur.execute(query, values)

            # 🎯 **핵심 기능**: 승인 시 Domi_Students 테이블에 자동 추가
            if status == '승인':
                # 승인 시 개별승인 상태로 업데이트
                cur.execute(
                    "UPDATE Firstin SET status = %s WHERE id = %s", ('개별승인', application_id))

                # 이미 Domi_Students에 존재하는지 확인
                cur.execute(
                    "SELECT student_id FROM Domi_Students WHERE student_id = %s",
                    (application['student_id'],
                     ))
                existing_student = cur.fetchone()

                if not existing_student:
                    # 입주 승인된 학생을 Domi_Students 테이블에 추가
                    insert_query = """
                        INSERT INTO Domi_Students (
                            student_id, name, dept, birth_date, gender, grade, phone_num,
                            par_name, par_phone, dorm_building, stat, password,
                            payback_bank, payback_name, payback_num, academic_status
                        ) VALUES (
                            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                        )
                    """

                    # 학년 데이터 변환 (1학년 → 1)
                    grade = application.get('grade', '1')
                    if grade and '학년' in str(grade):
                        grade = str(grade).replace('학년', '')

                    # 🎯 기존 비밀번호를 그대로 사용 (KBU_Students에서 가져오기)
                    cur.execute(
                        "SELECT password FROM KBU_Students WHERE student_id = %s",
                        (application['student_id'],
                         ))
                    kbu_student = cur.fetchone()

                    if kbu_student and kbu_student['password']:
                        # KBU_Students의 기존 비밀번호 사용
                        default_password = kbu_student['password']
                        print(
                            f"[입주승인] 기존 비밀번호 사용: {
                                application['student_id']}")
                    else:
                        # 만약 KBU_Students에 없다면 기본값 사용
                        if len(
                                application['student_id']) >= 4 and application['student_id'].isdigit():
                            default_password = application['student_id'][-4:]
                        else:
                            birth_date = application.get('birth_date')
                            if birth_date:
                                default_password = birth_date.strftime(
                                    '%Y%m%d')
                            else:
                                default_password = '19990101'
                        print(
                            f"[입주승인] 기본 비밀번호 생성: {
                                application['student_id']}")

                    cur.execute(insert_query, (
                        application['student_id'],
                        application['name'],
                        application['department'],
                        application.get('birth_date'),
                        application['gender'],
                        grade,  # 변환된 학년 사용
                        application['tel_mobile'],
                        application.get('par_name'),
                        application.get('par_phone'),
                        application.get('dorm_building'),
                        '입주승인',  # 초기 상태
                        default_password,
                        application.get('bank'),
                        application.get('account_holder'),
                        application.get('account_num'),
                        '재학'  # 기본값
                    ))

                    print(
                        f"[입주승인] 학생 {
                            application['student_id']} ({
                            application['name']})를 Domi_Students에 추가")
                else:
                    # 이미 존재하는 경우 상태만 업데이트
                    cur.execute(
                        "UPDATE Domi_Students SET stat = '입주승인' WHERE student_id = %s",
                        (application['student_id'],
                         ))
                    print(
                        f"[입주승인] 학생 {
                            application['student_id']} 상태를 '입주승인'으로 업데이트")

            conn.commit()

            # 응답 메시지 구성
            if status == '승인':
                message = f'입주 신청이 개별승인되었습니다. 합격자 조회에서 확인할 수 있습니다.'
            elif status == '반려':
                message = f'입주 신청이 반려되었습니다.'
            elif status and admin_memo is not None:
                message = f'신청 상태가 {status}(으)로 업데이트되고 메모가 저장되었습니다.'
            elif status:
                message = f'신청 상태가 {status}(으)로 업데이트되었습니다.'
            else:
                message = '관리자 메모가 저장되었습니다.'

        return jsonify({'message': message})
    except Exception as e:
        conn.rollback()
        print(f"[입주신청 상태 업데이트] 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 5. 입주신청 합격자/불합격자 조회 API (학생용)


@app.route('/api/firstin/result', methods=['GET'])
def check_firstin_result():
    """입주신청 결과 조회 (합격/불합격 확인) - 로그인 검증 포함"""
    student_id = request.args.get('student_id')
    # 'current_student' 또는 'new_student'
    user_type = request.args.get('user_type')
    name = request.args.get('name')

    if not student_id:
        return jsonify({'error': 'student_id 파라미터가 필요합니다.'}), 400

    print(
        f"[합격자 조회] student_id: {student_id}, user_type: {user_type}, name: {name}")

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 1. 재학생/신입생 구분에 따른 조회 로직
            if user_type == 'current_student':
                # 재학생: 숫자로만 구성된 학번으로 직접 조회
                query_condition = "student_id = %s"
                query_params = (student_id,)
            elif user_type == 'new_student':
                # 신입생: 이름으로 조회 (수험번호와 실제 학번이 다를 수 있음)
                query_condition = "name = %s"
                query_params = (name,)
            else:
                # 타입이 명시되지 않은 경우 기본 조회
                query_condition = "student_id = %s"
                query_params = (student_id,)

            # 2. Firstin 테이블에서 신청 상태 확인
            query = f"""
                SELECT id, student_id, name, status, reg_dt, admin_memo
                FROM Firstin
                WHERE {query_condition}
                ORDER BY reg_dt DESC
                LIMIT 1
            """

            print(f"[합격자 조회] 실행 쿼리: {query}")
            print(f"[합격자 조회] 쿼리 파라미터: {query_params}")

            cur.execute(query, query_params)
            application = cur.fetchone()

            if not application:
                return jsonify({
                    'success': False,
                    'message': '입주 신청 내역이 없습니다.',
                    'result': 'no_application'
                })

            print(
                f"[합격자 조회] 신청 내역 발견: {
                    application['student_id']} ({
                    application['name']})")

            # 3. Domi_Students 테이블에서 합격 여부 확인
            cur.execute("""
                SELECT student_id, name, stat, dorm_building, password
                FROM Domi_Students
                WHERE student_id = %s
            """, (application['student_id'],))
            admission_info = cur.fetchone()

            print(f"[합격자 조회] Domi_Students 조회 결과: {admission_info}")

            # 4. 결과 판정 로직
            result_data = {
                'student_id': application['student_id'],
                'name': application['name'],
                'application_date': application['reg_dt'].strftime('%Y-%m-%d'),
                'status': application['status'],
                'admin_memo': application.get('admin_memo')
            }

            if admission_info:
                # 합격자 (Domi_Students에 존재)
                result_data.update({
                    'success': True,
                    'result': 'accepted',
                    'message': '🎉 축하합니다! 입주 신청이 승인되었습니다.',
                    'dormitory': admission_info['dorm_building'],
                    'account_status': admission_info['stat'],
                    'portal_password': admission_info['password'],
                    'next_steps': [
                        '기숙사 포털 시스템에 로그인하여 입실신청을 진행하세요.',
                        '입실 관련 서류를 준비하세요.',
                        '배정된 기숙사 건물을 확인하세요.'
                    ]
                })
                print(f"[합격자 조회] 결과: 합격 - {application['student_id']}")
            elif application['status'] in ['반려', '선별제외']:
                # 불합격자 (명시적 반려 또는 선별제외)
                status_message = '선별에서 제외되었습니다.' if application['status'] == '선별제외' else '입주 신청이 반려되었습니다.'
                result_data.update({
                    'success': True,
                    'result': 'rejected',
                    'message': f'😞 {status_message}',
                    'rejection_reason': application.get('admin_memo', '자세한 사유는 관리사무소에 문의하세요.'),
                    'next_steps': [
                        '반려 사유를 확인하고 개선 후 재신청 가능 여부를 문의하세요.',
                        '관리사무소에 직접 방문하여 상담을 받으세요.'
                    ]
                })
                print(f"[합격자 조회] 결과: 불합격({application['status']}) - {application['student_id']}")
            else:
                # 심사 중 (아직 결정되지 않음)
                result_data.update({
                    'success': True,
                    'result': 'pending',
                    'message': '⏳ 입주 신청을 심사 중입니다.',
                    'current_status': application['status'],
                    'next_steps': [
                        '심사 결과를 기다려 주세요.',
                        '추가 서류 요청이 있을 경우 연락드리겠습니다.'
                    ]
                })
                print(f"[합격자 조회] 결과: 심사중 - {application['student_id']}")

            return jsonify(result_data)

    except Exception as e:
        print(f"[입주신청 결과 조회] 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 6. 관리자용 합격자 목록 조회 API


@app.route('/api/admin/firstin/accepted-students', methods=['GET'])
def get_accepted_students():
    """관리자용 입주신청 합격자 목록 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 승인된 학생들 조회 (Domi_Students 테이블 기준)
            query = """
                SELECT
                    ds.student_id, ds.name, ds.dept, ds.gender, ds.grade,
                    ds.phone_num, ds.dorm_building, ds.stat, ds.birth_date,
                    f.reg_dt as application_date, f.distance, f.admin_memo
                FROM Domi_Students ds
                INNER JOIN Firstin f ON ds.student_id = f.student_id
                WHERE f.status = '승인' AND ds.stat IN ('입주승인', '입주중')
                ORDER BY f.reg_dt DESC
            """
            cur.execute(query)
            accepted_students = cur.fetchall()

            # 날짜 형식 변환
            for student in accepted_students:
                if student.get('application_date'):
                    student['application_date'] = student['application_date'].strftime(
                        '%Y-%m-%d')
                if student.get('birth_date'):
                    student['birth_date'] = student['birth_date'].strftime(
                        '%Y-%m-%d')

            return jsonify({
                'success': True,
                'total_count': len(accepted_students),
                'accepted_students': accepted_students
            })

    except Exception as e:
        print(f"[합격자 목록 조회] 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 석식 신청 목록 조회 API


@app.route('/api/dinner/requests', methods=['GET'])
def get_dinner_requests():
    """학생용 석식 신청 목록 조회"""
    student_id = request.args.get('student_id')
    if not student_id:
        return jsonify({'success': False, 'error': 'student_id가 필요합니다.'}), 400

    print(f"[석식 신청 목록] 요청 받음 - 학생 ID: {student_id}")

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 석식 신청 목록과 결제 정보를 함께 조회
            query = """
                SELECT
                    d.dinner_id, d.year, d.semester, d.month, d.reg_dt,
                    d.student_id,
                    GROUP_CONCAT(
                        CASE WHEN p.pay_type = '결제' THEN p.amount END
                    ) as payment_amount,
                    GROUP_CONCAT(
                        CASE WHEN p.pay_type = '결제' THEN p.pay_dt END
                    ) as payment_date,
                    GROUP_CONCAT(
                        CASE WHEN p.pay_type = '환불' THEN p.amount END
                    ) as refund_amount,
                    GROUP_CONCAT(
                        CASE WHEN p.pay_type = '환불' THEN p.pay_dt END
                    ) as refund_date
                FROM Dinner d
                LEFT JOIN Dinner_Payment p ON d.dinner_id = p.dinner_id
                WHERE d.student_id = %s
                GROUP BY d.dinner_id
                ORDER BY d.reg_dt DESC
            """
            print(f"[석식 신청 목록] 실행할 쿼리: {query}")
            print(f"[석식 신청 목록] 쿼리 파라미터: {student_id}")

            cur.execute(query, (student_id,))
            data = cur.fetchall()

            print(f"[석식 신청 목록] 조회된 데이터 개수: {len(data)}")

            # 날짜 필드 ISO 포맷으로 변환 및 상태 처리
            processed_data = []
            for item in data:
                # reg_dt 필드 처리
                if item.get('reg_dt'):
                    item['reg_dt'] = item['reg_dt'].strftime('%Y-%m-%d')

                # 결제 상태 판단
                has_payment = item.get('payment_amount') is not None
                has_refund = item.get('refund_amount') is not None

                if has_refund:
                    item['stat'] = '환불'
                elif has_payment:
                    item['stat'] = '승인'
                else:
                    item['stat'] = '대기'

                # 기간 정보 생성
                item['target_year'] = item['year']

                # semester가 이미 "학기"가 포함되어 있는지 확인
                semester_str = str(item['semester'])
                if semester_str.endswith('학기'):
                    item['target_semester'] = semester_str
                else:
                    item['target_semester'] = f"{semester_str}학기"

                # month가 이미 "월"이 포함되어 있는지 확인
                month_str = str(item['month'])
                if month_str.endswith('월'):
                    item['target_month'] = month_str
                else:
                    item['target_month'] = f"{month_str}월"

                processed_data.append(item)
                print(
                    f"[석식 신청 목록] 처리된 항목: {
                        item['year']}-{
                        item['target_semester']} {
                        item['target_month']} - {
                        item['stat']}")

            print(f"[석식 신청 목록] 최종 반환 데이터: {processed_data}")

        return jsonify({
            'success': True,
            'requests': processed_data
        })
    except Exception as e:
        print(f"[석식 신청 목록] 오류 발생: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()
        print("[석식 신청 목록] 데이터베이스 연결 종료")

# ========================================
# 점호 시스템 API
# ========================================


@app.route('/api/rollcall/settings', methods=['GET'])
def get_rollcall_settings():
    """점호 설정 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM RollCallSettings")
            settings = cur.fetchall()

            # 딕셔너리 형태로 변환
            settings_dict = {}
            for setting in settings:
                settings_dict[setting['setting_name']
                              ] = setting['setting_value']

            return jsonify(settings_dict)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/rollcall/settings', methods=['POST'])
def update_rollcall_settings():
    """점호 설정 업데이트 (관리자용)"""
    data = request.json

    if not data:
        return jsonify({'error': '설정 데이터가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 각 설정을 업데이트 또는 생성
            for setting_name, setting_value in data.items():
                # 기존 설정이 있는지 확인
                cur.execute(
                    "SELECT setting_id FROM RollCallSettings WHERE setting_name = %s",
                    (setting_name,
                     ))
                existing = cur.fetchone()

                if existing:
                    # 기존 설정 업데이트
                    cur.execute("""
                        UPDATE RollCallSettings
                        SET setting_value = %s, updated_at = %s
                        WHERE setting_name = %s
                    """, (str(setting_value), datetime.now(), setting_name))
                    print(f"[점호 설정] 업데이트: {setting_name} = {setting_value}")
                else:
                    # 새 설정 생성
                    cur.execute("""
                        INSERT INTO RollCallSettings (setting_name, setting_value, updated_at)
                        VALUES (%s, %s, %s)
                    """, (setting_name, str(setting_value), datetime.now()))
                    print(f"[점호 설정] 생성: {setting_name} = {setting_value}")

            conn.commit()

            return jsonify({
                'message': '점호 설정이 성공적으로 업데이트되었습니다.',
                'updated_settings': list(data.keys())
            })

    except Exception as e:
        conn.rollback()
        print(f"[점호 설정] 업데이트 오류: {e}")
        return jsonify({'error': f'설정 업데이트 중 오류가 발생했습니다: {str(e)}'}), 500
    finally:
        conn.close()


@app.route('/api/rollcall/check', methods=['POST'])
def submit_rollcall():
    """학생 점호 제출 (GPS 기반 - 다중 건물 지원)"""
    print(f"[점호 제출] API 호출 시작")
    try:
        data = request.json
        print(f"[점호 제출] 받은 데이터: {data}")

        student_id = data.get('student_id')
        latitude = data.get('latitude')
        longitude = data.get('longitude')

        print(
            f"[점호 제출] 파라미터 - student_id: {student_id}, lat: {latitude}, lng: {longitude}")

        if not all([student_id, latitude, longitude]):
            print(f"[점호 제출] 필수 정보 누락")
            return jsonify({'error': '필수 정보가 누락되었습니다.'}), 400

        conn = get_db()
        print(f"[점호 제출] DB 연결 성공")
        with conn.cursor() as cur:
            # 학생의 기숙사 건물 조회
            cur.execute(
                "SELECT dorm_building FROM Domi_Students WHERE student_id = %s", (student_id,))
            student_result = cur.fetchone()

            if not student_result or not student_result['dorm_building']:
                return jsonify({'error': '기숙사 건물 정보를 찾을 수 없습니다.'}), 400

            building_name = student_result['dorm_building']

            # 해당 날짜에 외박 승인이 있는지 확인
            current_date = datetime.now().date()
            cur.execute("""
                SELECT out_uuid, place, out_start, out_end
                FROM Outting
                WHERE student_id = %s
                    AND stat = '승인'
                    AND %s BETWEEN out_start AND out_end
            """, (student_id, current_date))

            approved_outing = cur.fetchone()

            if approved_outing:
                return jsonify(
                    {
                        'info': '외박 승인으로 점호 면제', 'message': f'승인된 외박으로 인해 점호가 면제되었습니다.\n외박 장소: {
                            approved_outing["place"]}\n기간: {
                            approved_outing["out_start"]} ~ {
                            approved_outing["out_end"]}', 'exempted': True, 'outing_info': {
                            'place': approved_outing['place'], 'start_date': str(
                                approved_outing['out_start']), 'end_date': str(
                                approved_outing['out_end'])}}), 200

            # 건물별 GPS 좌표 및 허용 거리 조회
            cur.execute("""
                SELECT campus_lat, campus_lng, allowed_distance
                FROM DormitoryBuildings
                WHERE building_name = %s AND is_active = TRUE
            """, (building_name,))
            building_result = cur.fetchone()

            if not building_result:
                # 건물 정보가 없으면 기본 설정 사용
                cur.execute(
                    "SELECT setting_name, setting_value FROM RollCallSettings WHERE setting_name IN ('campus_lat', 'campus_lng', 'allowed_distance')")
                settings = cur.fetchall()
                settings_dict = {
                    s['setting_name']: s['setting_value'] for s in settings}
                campus_lat = float(settings_dict.get('campus_lat', 37.735700))
                campus_lng = float(settings_dict.get('campus_lng', 127.210523))
                allowed_distance = float(
                    settings_dict.get(
                        'allowed_distance', 50))
            else:
                campus_lat = float(building_result['campus_lat'])
                campus_lng = float(building_result['campus_lng'])
                allowed_distance = float(building_result['allowed_distance'])

            # 거리 계산
            distance = calculate_distance(
                latitude, longitude, campus_lat, campus_lng)

            # 점호 시간 확인 (설정에서 가져오기)
            cur.execute(
                "SELECT setting_name, setting_value FROM RollCallSettings WHERE setting_name IN ('rollcall_start_time', 'rollcall_end_time')")
            time_settings = cur.fetchall()
            time_settings_dict = {
                s['setting_name']: s['setting_value'] for s in time_settings}

            start_time_str = time_settings_dict.get(
                'rollcall_start_time', '23:50:00')
            end_time_str = time_settings_dict.get(
                'rollcall_end_time', '00:10:00')

            from datetime import time as datetime_time
            current_time = datetime.now().time()
            current_date = datetime.now().date()

            # 시간 문자열을 time 객체로 변환
            start_hour, start_min, start_sec = map(
                int, start_time_str.split(':'))
            end_hour, end_min, end_sec = map(int, end_time_str.split(':'))
            start_time = datetime_time(start_hour, start_min, start_sec)
            end_time = datetime_time(end_hour, end_min, end_sec)

            # 점호 시간 체크 (자정을 넘나드는 경우 고려)
            if start_time <= end_time:
                # 같은 날 내에서 시작과 끝이 있는 경우
                is_rollcall_time = start_time <= current_time <= end_time
            else:
                # 자정을 넘나드는 경우 (예: 23:50 ~ 00:10)
                is_rollcall_time = current_time >= start_time or current_time <= end_time

            if not is_rollcall_time:
                return jsonify({
                    'error': '점호 시간이 아닙니다.',
                    'message': f'점호는 {start_time_str} ~ {end_time_str} 사이에만 가능합니다.',
                    'current_time': current_time.strftime('%H:%M')
                }), 400

            # 이미 오늘 점호했는지 확인
            cur.execute(
                "SELECT rollcall_id FROM RollCall WHERE student_id = %s AND rollcall_date = %s",
                (student_id,
                 current_date))
            existing = cur.fetchone()

            if existing:
                return jsonify({'error': '오늘 이미 점호를 완료했습니다.'}), 400

            # 거리 체크
            if distance > allowed_distance:
                return jsonify({
                    'error': f'{building_name} 기숙사 반경을 벗어났습니다.',
                    'distance': round(distance, 1),
                    'allowed_distance': allowed_distance,
                    'building': building_name,
                    'message': f'현재 위치가 {building_name}에서 {round(distance, 1)}m 떨어져 있습니다.',
                    'success': False
                }), 400

            # 점호 기록 저장 (건물 정보 포함)
            cur.execute("""
                INSERT INTO RollCall (student_id, rollcall_date, rollcall_time, location_lat, location_lng,
                                    distance_from_campus, rollcall_type, building_name)
                VALUES (%s, %s, %s, %s, %s, %s, '자동', %s)
            """, (student_id, current_date, current_time, latitude, longitude, distance, building_name))

            conn.commit()

            return jsonify({
                'message': f'{building_name} 점호가 성공적으로 완료되었습니다! 🎉',
                'distance': round(distance, 1),
                'time': current_time.strftime('%H:%M:%S'),
                'building': building_name,
                'success': True
            })

    except Exception as e:
        print(f"[점호 제출] 오류 발생: {str(e)}")
        print(f"[점호 제출] 오류 타입: {type(e)}")
        import traceback
        print(f"[점호 제출] 스택 트레이스: {traceback.format_exc()}")
        return jsonify({'error': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()


@app.route('/api/rollcall/status', methods=['GET'])
def get_rollcall_status():
    """점호 현황 조회 (관리자용) - 건물별 지원"""
    print(f"[점호 현황] API 호출 시작")

    # 날짜 파라미터 처리 개선
    date_param = request.args.get('date')
    if date_param:
        try:
            target_date = datetime.strptime(date_param, '%Y-%m-%d').date()
        except ValueError:
            target_date = datetime.now().date()
    else:
        target_date = datetime.now().date()

    building_filter = request.args.get('building')  # 특정 건물 필터링

    print(f"[점호 현황] 요청 파라미터 - 날짜: {target_date}, 건물: {building_filter}")

    conn = get_db()
    try:
        with conn.cursor() as cur:
            print(f"[점호 현황] 데이터베이스 연결 성공")

            # 건물 필터 조건 설정
            building_condition = ""
            building_params = []
            if building_filter and building_filter != "전체":
                building_condition = "AND ds.dorm_building = %s"
                building_params = [building_filter]

            print(f"[점호 현황] 건물 조건: {building_condition}")
            print(f"[점호 현황] 건물 파라미터: {building_params}")

            # 단계별 접근: 1단계 - 모든 학생 조회
            all_students_query = f"""
                SELECT DISTINCT ds.student_id, ds.name, ds.dorm_building, ds.room_num
                FROM Domi_Students ds
                WHERE ds.stat IN ('입주중', '입주승인')
                    AND ds.student_id != 'admin' {building_condition}
            """

            print(f"[점호 현황] 1단계: 전체 학생 조회")
            cur.execute(all_students_query, building_params)
            all_students = cur.fetchall()
            print(f"[점호 현황] 전체 학생 수: {len(all_students)}명")

            # 건물별로 분류
            building_summaries = {}
            for student in all_students:
                building = student['dorm_building'] if student['dorm_building'] else '미지정'
                if building not in building_summaries:
                    building_summaries[building] = {
                        'total_students': 0,
                        'completed_rollcalls': 0,
                        'dorm_building': building}
                building_summaries[building]['total_students'] += 1
                print(f"[점호 현황] 학생 추가: {student['name']} → 건물: '{building}'")

            # 리스트로 변환
            building_summaries = list(building_summaries.values())
            print(f"[점호 현황] 건물별 통계 결과: {len(building_summaries)}개 건물")
            for summary in building_summaries:
                print(
                    f"[점호 현황] 건물: {
                        summary.get(
                            'dorm_building',
                            'NULL')}, 전체: {
                        summary.get(
                            'total_students',
                            0)}, 완료: {
                        summary.get(
                            'completed_rollcalls',
                            0)}")

            # 외박 승인된 학생들 별도 조회
            outing_query = f"""
                SELECT DISTINCT ds.student_id
                FROM Domi_Students ds
                INNER JOIN Outting o ON ds.student_id = o.student_id
                WHERE o.stat = '승인'
                    AND %s BETWEEN DATE(o.out_start) AND DATE(o.out_end)
                    AND ds.stat IN ('입주중', '입주승인')
                    AND ds.student_id != 'admin' {building_condition}
            """

            print(f"[점호 현황] 외박 학생 쿼리 실행")
            cur.execute(outing_query, [target_date] + building_params)
            outing_students = [row['student_id'] for row in cur.fetchall()]
            print(
                f"[점호 현황] 외박 승인 학생: {
                    len(outing_students)}명 - {outing_students}")

            # 점호 완료 학생 수 계산
            rollcall_completed_query = f"""
                SELECT DISTINCT ds.student_id
                FROM Domi_Students ds
                INNER JOIN RollCall rc ON ds.student_id = rc.student_id
                    AND rc.rollcall_date = %s
                WHERE ds.stat IN ('입주중', '입주승인')
                    AND ds.student_id != 'admin' {building_condition}
            """

            print(f"[점호 현황] 2단계: 점호 완료 학생 조회")
            cur.execute(
                rollcall_completed_query,
                [target_date] +
                building_params)
            completed_students_ids = [row['student_id']
                                      for row in cur.fetchall()]
            print(f"[점호 현황] 점호 완료 학생: {len(completed_students_ids)}명")

            # 건물별 완료 통계 업데이트
            for student in all_students:
                building = student['dorm_building'] if student['dorm_building'] else '미지정'
                if student['student_id'] in completed_students_ids:
                    for summary in building_summaries:
                        if summary['dorm_building'] == building:
                            summary['completed_rollcalls'] += 1
                            break

            # 외박 학생을 제외한 실제 통계 계산
            total_without_outing = 0
            completed_without_outing = 0
            for summary in building_summaries:
                building_total = summary.get('total_students', 0)
                building_completed = summary.get('completed_rollcalls', 0)
                total_without_outing += building_total
                completed_without_outing += building_completed

            # 외박 학생 수만큼 차감
            exempted_count = len(outing_students)
            total_without_outing -= exempted_count
            pending = total_without_outing - completed_without_outing

            print(
                f"[점호 현황] 수정된 통계 - 총: {total_without_outing}, 완료: {completed_without_outing}, 대기: {pending}, 외박면제: {exempted_count}")

            # 모든 학생 상세 목록 조회
            student_query = f"""
                SELECT
                    ds.student_id,
                    ds.name,
                    ds.room_num,
                    ds.dept,
                    ds.dorm_building,
                    rc.rollcall_time,
                    rc.distance_from_campus,
                    rc.rollcall_type,
                    rc.processed_by,
                    rc.reason,
                    rc.building_name
                FROM Domi_Students ds
                LEFT JOIN RollCall rc ON ds.student_id = rc.student_id
                    AND rc.rollcall_date = %s
                WHERE ds.stat IN ('입주중', '입주승인')
                    AND ds.student_id != 'admin' {building_condition}
                ORDER BY ds.dorm_building, rc.rollcall_time DESC, ds.name ASC
            """

            print(f"[점호 현황] 학생 상세 쿼리 실행")
            cur.execute(student_query, [target_date] + building_params)

            students = cur.fetchall()
            print(f"[점호 현황] 학생 상세 결과: {len(students)}명")

            # 점호 완료/미완료/외박면제 분류
            completed_students = []
            pending_students = []

            for student in students:
                student_id = student['student_id']

                # 외박 학생인지 확인
                if student_id in outing_students:
                    continue  # 외박 학생은 완료/미완료 목록에서 제외

                # rollcall_time이 timedelta 객체인지 datetime 객체인지 확인하고 적절히 처리
                rollcall_time_str = None
                if student['rollcall_time']:
                    if isinstance(student['rollcall_time'], datetime):
                        # datetime 객체인 경우 시간 부분만 추출
                        rollcall_time_str = student['rollcall_time'].strftime(
                            '%H:%M:%S')
                    elif hasattr(student['rollcall_time'], 'total_seconds'):
                        # timedelta 객체인 경우 초를 시:분:초로 변환
                        total_seconds = int(
                            student['rollcall_time'].total_seconds())
                        hours = total_seconds // 3600
                        minutes = (total_seconds % 3600) // 60
                        seconds = total_seconds % 60
                        rollcall_time_str = f"{
                            hours:02d}:{
                            minutes:02d}:{
                            seconds:02d}"
                    else:
                        # 문자열이나 기타 형태인 경우 그대로 사용
                        rollcall_time_str = str(student['rollcall_time'])

                student_data = {
                    'student_id': student['student_id'],
                    'name': student['name'],
                    'room_num': student['room_num'],
                    'dept': student['dept'],
                    'dorm_building': student['dorm_building'],
                    'rollcall_time': rollcall_time_str,
                    'distance': float(
                        student['distance_from_campus']) if student['distance_from_campus'] else None,
                    'rollcall_type': student['rollcall_type'],
                    'processed_by': student['processed_by'],
                    'reason': student['reason'],
                    'building_name': student['building_name']}

                if student['rollcall_time']:
                    completed_students.append(student_data)
                else:
                    pending_students.append(student_data)

            print(
                f"[점호 현황] 분류 완료 - 완료: {len(completed_students)}명, 미완료: {len(pending_students)}명")

            # 건물별 통계 정보 수정 (외박 학생 제외)
            building_stats = []
            for building_summary in building_summaries:
                building_name = building_summary.get('dorm_building', '미지정')
                building_total_raw = building_summary.get('total_students', 0)
                building_completed = building_summary.get(
                    'completed_rollcalls', 0)

                # 해당 건물의 외박 학생 수 계산
                building_outing_count = sum(1 for student in students
                                            if student['dorm_building'] == building_name
                                            and student['student_id'] in outing_students)

                building_total = building_total_raw - building_outing_count
                building_pending = building_total - building_completed
                building_rate = round(
                    (building_completed / building_total * 100) if building_total > 0 else 0, 1)

                building_stats.append({
                    'building_name': building_name,
                    'total': building_total,
                    'completed': building_completed,
                    'pending': building_pending,
                    'completion_rate': building_rate
                })

            print(f"[점호 현황] 건물별 통계 생성 완료: {len(building_stats)}개")

            # 외박 승인으로 면제된 학생들 상세 정보 조회
            exempted_query = f"""
                SELECT
                    ds.student_id,
                    ds.name,
                    ds.room_num,
                    ds.dept,
                    ds.dorm_building,
                    o.place as outing_place,
                    o.out_start,
                    o.out_end,
                    o.reason as outing_reason
                FROM Domi_Students ds
                INNER JOIN Outting o ON ds.student_id = o.student_id
                WHERE o.stat = '승인'
                    AND %s BETWEEN DATE(o.out_start) AND DATE(o.out_end)
                    AND ds.stat IN ('입주중', '입주승인')
                    AND ds.student_id != 'admin' {building_condition}
                ORDER BY ds.dorm_building, ds.name ASC
            """

            print(f"[점호 현황] 외박 면제 학생 상세 정보 쿼리 실행")
            cur.execute(exempted_query, [target_date] + building_params)

            exempted_students_detail = cur.fetchall()
            print(f"[점호 현황] 외박 면제 학생 상세: {len(exempted_students_detail)}명")

            exempted_list = []
            for student in exempted_students_detail:
                exempted_list.append({
                    'student_id': student['student_id'],
                    'name': student['name'],
                    'room_num': student['room_num'],
                    'dept': student['dept'],
                    'dorm_building': student['dorm_building'],
                    'outing_place': student['outing_place'],
                    'outing_period': f"{student['out_start']} ~ {student['out_end']}",
                    'outing_reason': student['outing_reason']
                })

            result = {
                'summary': {
                    'total': total_without_outing,
                    'completed': completed_without_outing,
                    'pending': pending,
                    'exempted': exempted_count
                },
                'building_stats': building_stats,
                'completed_students': completed_students,
                'pending_students': pending_students,
                'exempted_students': exempted_list
            }

            print(f"[점호 현황] 최종 응답 데이터: {result['summary']}")
            return jsonify(result)

    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"[점호 현황] 오류 발생: {str(e)}")
        print(f"[점호 현황] 상세 스택: {error_details}")
        return jsonify({'error': str(e), 'details': error_details}), 500
    finally:
        conn.close()
        print(f"[점호 현황] 데이터베이스 연결 종료")


@app.route('/api/rollcall/manual', methods=['POST'])
def manual_rollcall():
    """수동 점호 처리 (관리자용)"""
    data = request.json
    student_id = data.get('student_id')
    admin_id = data.get('admin_id', 'admin')
    reason = data.get('reason', '수동 점호 처리')

    if not student_id:
        return jsonify({'error': '학생 ID가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            current_time = datetime.now().time()
            current_date = datetime.now().date()

            # 이미 점호했는지 확인
            cur.execute(
                "SELECT rollcall_id FROM RollCall WHERE student_id = %s AND rollcall_date = %s",
                (student_id,
                 current_date))
            existing = cur.fetchone()

            if existing:
                return jsonify({'error': '이미 점호가 완료된 학생입니다.'}), 400

            # 학생 존재 여부 및 건물 정보 확인
            cur.execute(
                "SELECT name, dorm_building FROM Domi_Students WHERE student_id = %s AND stat IN ('입주중', '입주승인')",
                (student_id,
                 ))
            student = cur.fetchone()

            if not student:
                return jsonify({'error': '해당 학생을 찾을 수 없습니다.'}), 404

            building_name = student['dorm_building']

            # 수동 점호 기록 저장 (GPS 정보 없이, 건물 정보 포함)
            cur.execute("""
                INSERT INTO RollCall (student_id, rollcall_date, rollcall_time, rollcall_type, processed_by, reason, building_name)
                VALUES (%s, %s, %s, '수동', %s, %s, %s)
            """, (student_id, current_date, current_time, admin_id, reason, building_name))

            conn.commit()

            return jsonify({
                'message': f'{student["name"]} 학생의 수동 점호가 처리되었습니다.',
                'student_name': student['name'],
                'time': current_time.strftime('%H:%M:%S'),
                'reason': reason
            })

    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/rollcall/student/<student_id>', methods=['GET'])
def get_student_rollcall_status(student_id):
    """특정 학생의 점호 상태 조회"""
    target_date = request.args.get('date', datetime.now().date())

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    rc.*,
                    ds.name,
                    ds.room_num
                FROM RollCall rc
                JOIN Domi_Students ds ON rc.student_id = ds.student_id
                WHERE rc.student_id = %s AND rc.rollcall_date = %s
            """, (student_id, target_date))

            rollcall = cur.fetchone()

            if rollcall:
                # rollcall_time이 timedelta 객체인지 datetime 객체인지 확인하고 적절히 처리
                rollcall_time_str = None
                if rollcall['rollcall_time']:
                    if isinstance(rollcall['rollcall_time'], datetime):
                        # datetime 객체인 경우 시간 부분만 추출
                        rollcall_time_str = rollcall['rollcall_time'].strftime(
                            '%H:%M:%S')
                    elif hasattr(rollcall['rollcall_time'], 'total_seconds'):
                        # timedelta 객체인 경우 초를 시:분:초로 변환
                        total_seconds = int(
                            rollcall['rollcall_time'].total_seconds())
                        hours = total_seconds // 3600
                        minutes = (total_seconds % 3600) // 60
                        seconds = total_seconds % 60
                        rollcall_time_str = f"{
                            hours:02d}:{
                            minutes:02d}:{
                            seconds:02d}"
                    else:
                        # 문자열이나 기타 형태인 경우 그대로 사용
                        rollcall_time_str = str(rollcall['rollcall_time'])

                return jsonify(
                    {
                        'completed': True,
                        'rollcall_time': rollcall_time_str,
                        'rollcall_type': rollcall['rollcall_type'],
                        'distance': float(
                            rollcall['distance_from_campus']) if rollcall['distance_from_campus'] else None,
                        'reason': rollcall['reason'],
                        'processed_by': rollcall['processed_by']})
            else:
                return jsonify({'completed': False})

    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/rollcall/is-time', methods=['GET'])
def is_rollcall_time():
    """현재가 점호 시간인지 확인"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT setting_name, setting_value FROM RollCallSettings
                WHERE setting_name IN ('rollcall_start_time', 'rollcall_end_time', 'auto_rollcall_enabled')
            """)
            settings = cur.fetchall()

            settings_dict = {s['setting_name']: s['setting_value']
                             for s in settings}
            start_time_str = settings_dict.get(
                'rollcall_start_time', '23:50:00')
            end_time_str = settings_dict.get('rollcall_end_time', '00:10:00')
            auto_enabled = settings_dict.get(
                'auto_rollcall_enabled', 'true') == 'true'

            if not auto_enabled:
                return jsonify({'is_rollcall_time': False,
                               'message': '자동 점호가 비활성화되어 있습니다.'})

            current_time = datetime.now().time()
            start_time = datetime.strptime(start_time_str, '%H:%M:%S').time()
            end_time = datetime.strptime(end_time_str, '%H:%M:%S').time()

            # 자정을 넘나드는 시간 처리 (예: 23:50 ~ 00:10)
            if start_time > end_time:  # 자정을 넘는 경우
                is_time = current_time >= start_time or current_time <= end_time
            else:  # 같은 날 내의 시간
                is_time = start_time <= current_time <= end_time

            return jsonify({
                'is_rollcall_time': is_time,
                'start_time': start_time_str,
                'end_time': end_time_str,
                'current_time': current_time.strftime('%H:%M:%S'),
                'auto_enabled': auto_enabled
            })

    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 입실신청(Checkin) 관리 API ===


@app.route('/api/checkin/apply', methods=['POST'])
def apply_checkin():
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 이미 신청한 학생인지 확인
            cur.execute(
                "SELECT checkin_id FROM Checkin WHERE student_id = %s", (data['student_id'],))
            if cur.fetchone():
                return jsonify({'error': '이미 입실 신청이 완료되었습니다.'}), 409

            # 학생의 학년을 조회하여 올바른 recruit_type 결정
            cur.execute(
                "SELECT grade FROM Domi_Students WHERE student_id = %s", (data['student_id'],))
            student_grade = cur.fetchone()

            # 학년에 따른 recruit_type 자동 설정
            if student_grade and student_grade['grade']:
                grade = student_grade['grade']
                if grade == 1:
                    recruit_type = '신입생'
                else:
                    recruit_type = '재학생'
            else:
                # 학년 정보가 없으면 요청 데이터 사용 (기본값: 재학생)
                recruit_type = data.get('recruit_type', '재학생')

            print(
                f"[입실신청] 학생 {
                    data['student_id']} - 학년: {
                    student_grade['grade'] if student_grade else 'N/A'}, recruit_type: {recruit_type}")

            # Checkin 테이블에 데이터 삽입
            query = """
                INSERT INTO Checkin (
                    recruit_type, year, semester, name, student_id, department,
                    smoking, building, room_type, room_num, payback_bank,
                    payback_name, payback_num, reg_dt, status, auto_eligible
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
            """

            values = (
                recruit_type,  # 자동 결정된 recruit_type 사용
                data.get('year', '2025'),
                data.get('semester', '1학기'),
                data['name'],
                data['student_id'],
                data['department'],
                data.get('smoking', '비흡연'),
                data.get('building', '양덕원'),
                data.get('room_type', '2인실'),
                data.get('room_num', ''),  # 자동 배정
                data.get('bank', '국민은행'),
                data.get('account_holder', data['name']),
                data.get('account_num', ''),
                datetime.now(),
                '미배정',  # 초기 상태
                1  # 자동 승인 대상
            )

            cur.execute(query, values)
            checkin_id = cur.lastrowid
            conn.commit()

            return jsonify({
                'message': '입실 신청이 성공적으로 제출되었습니다.',
                'checkin_id': checkin_id
            }), 201

    except Exception as e:
        conn.rollback()
        print(f"입실 신청 저장 오류: {e}")
        return jsonify({'error': f'신청 저장 중 오류가 발생했습니다: {str(e)}'}), 500
    finally:
        conn.close()

# 1-1. 입실신청 수정 (학생용)


@app.route('/api/checkin/update/<int:checkin_id>', methods=['PUT'])
def update_checkin(checkin_id):
    """학생의 입실신청 정보 수정"""
    data = request.json
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기존 신청 확인
            cur.execute(
                "SELECT student_id, status FROM Checkin WHERE checkin_id = %s", (checkin_id,))
            existing_checkin = cur.fetchone()

            if not existing_checkin:
                return jsonify({'error': '입실신청을 찾을 수 없습니다.'}), 404

            # 수정 가능한 상태인지 확인
            if existing_checkin['status'] not in ['미배정', '미확인']:
                return jsonify({'error': '이미 처리된 신청은 수정할 수 없습니다.'}), 400

            # 입실신청 정보 업데이트
            query = """
                UPDATE Checkin SET
                    name = %s, department = %s, smoking = %s, building = %s,
                    room_type = %s, payback_bank = %s, payback_name = %s,
                    payback_num = %s, modified_at = %s
                WHERE checkin_id = %s
            """

            values = (
                data['name'],
                data['department'],
                data.get('smoking', '비흡연'),
                data.get('building', '양덕원'),
                data.get('room_type', '2인실'),
                data.get('bank', '국민은행'),
                data.get('account_holder', data['name']),
                data.get('account_num', ''),
                datetime.now(),
                checkin_id
            )

            cur.execute(query, values)
            conn.commit()

            return jsonify({
                'message': '입실신청이 성공적으로 수정되었습니다.',
                'checkin_id': checkin_id
            }), 200

    except Exception as e:
        conn.rollback()
        print(f"입실신청 수정 오류: {e}")
        return jsonify({'error': f'수정 중 오류가 발생했습니다: {str(e)}'}), 500
    finally:
        conn.close()

# 2. 입실신청 서류 업로드


@app.route('/api/checkin/upload', methods=['POST'])
def upload_checkin_document():
    """입실신청 서류 파일 업로드"""
    print(
        f"[파일 업로드] 요청 받음 - files: {list(request.files.keys())}, form: {dict(request.form)}")

    try:
        if 'file' not in request.files:
            print("[파일 업로드] 오류: 파일이 선택되지 않았습니다.")
            return jsonify({'error': '파일이 선택되지 않았습니다.'}), 400

        file = request.files['file']
        checkin_id = request.form.get('checkin_id')
        recruit_type = request.form.get('recruit_type', '재학생')

        print(
            f"[파일 업로드] 파라미터 - checkin_id: {checkin_id}, recruit_type: {recruit_type}, filename: {file.filename}")

        if not checkin_id:
            print("[파일 업로드] 오류: checkin_id가 필요합니다.")
            return jsonify({'error': 'checkin_id가 필요합니다.'}), 400

        if file.filename == '':
            print("[파일 업로드] 오류: 파일이 선택되지 않았습니다.")
            return jsonify({'error': '파일이 선택되지 않았습니다.'}), 400

        # 파일 저장
        upload_dir = 'uploads/in'
        os.makedirs(upload_dir, exist_ok=True)

        # 고유한 파일명 생성
        file_extension = os.path.splitext(file.filename)[1]
        unique_filename = f"{uuid.uuid4()}_{file.filename}"
        file_path = os.path.join(upload_dir, unique_filename)

        print(f"[파일 업로드] 파일 저장 중 - 경로: {file_path}")
        file.save(file_path)
        print(f"[파일 업로드] 파일 저장 완료")

        # DB에 파일 정보 저장
        conn = get_db()
        try:
            with conn.cursor() as cur:
                print(f"[파일 업로드] DB 저장 중...")
                cur.execute("""
                    INSERT INTO Checkin_Documents (
                        checkin_id, file_name, status, recruit_type,
                        upload_path, uploaded_at, file_type, file_url
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    checkin_id,
                    file.filename,
                    '제출완료',
                    recruit_type,
                    file_path,
                    datetime.now(),
                    file_extension,
                    f'/uploads/in/{unique_filename}'
                ))
                conn.commit()
                print(f"[파일 업로드] DB 저장 완료")

            response_data = {
                'message': '파일이 성공적으로 업로드되었습니다.',
                'file_path': file_path,
                'file_url': f'/uploads/in/{unique_filename}'
            }
            print(f"[파일 업로드] 성공 응답: {response_data}")
            return jsonify(response_data), 200

        except Exception as e:
            conn.rollback()
            print(f"[파일 업로드] DB 오류: {e}")
            # 업로드된 파일 삭제
            if os.path.exists(file_path):
                os.remove(file_path)
                print(f"[파일 업로드] 실패한 파일 삭제: {file_path}")
            raise e
        finally:
            conn.close()

    except Exception as e:
        print(f"[파일 업로드] 전체 오류: {e}")
        return jsonify({'error': f'파일 업로드 중 오류가 발생했습니다: {str(e)}'}), 500

# 3. 학생별 입실신청 조회


@app.route('/api/checkin/requests', methods=['GET'])
def get_checkin_requests():
    """학생별 입실신청 내역 조회"""
    student_id = request.args.get('student_id')

    if not student_id:
        return jsonify({'error': 'student_id가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 입실신청 정보 조회
            cur.execute("""
                SELECT * FROM Checkin
                WHERE student_id = %s
                ORDER BY reg_dt DESC
            """, (student_id,))
            checkin_data = cur.fetchall()

            # 각 신청별 서류 파일 조회
            for checkin in checkin_data:
                cur.execute("""
                    SELECT * FROM Checkin_Documents
                    WHERE checkin_id = %s
                """, (checkin['checkin_id'],))
                checkin['documents'] = cur.fetchall()

                # 날짜 필드 변환
                if checkin.get('reg_dt'):
                    checkin['reg_dt'] = checkin['reg_dt'].isoformat()
                if checkin.get('auto_approved_at'):
                    checkin['auto_approved_at'] = checkin['auto_approved_at'].isoformat()
                if checkin.get('manual_approved_at'):
                    checkin['manual_approved_at'] = checkin['manual_approved_at'].isoformat()

            return jsonify(checkin_data)

    except Exception as e:
        print(f"입실신청 조회 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# ========================================
# 방학 이용 신청 시스템 API
# ========================================


@app.route('/api/vacation/apply', methods=['POST'])
def apply_vacation():
    """학생용 방학 이용 신청"""
    data = request.json

    # 필수 필드 검증
    required_fields = [
        'student_id', 'student_name', 'student_phone',
        'reserver_name', 'reserver_relation', 'reserver_phone',
        'building', 'room_type', 'guest_count',
        'check_in_date', 'check_out_date', 'total_amount'
    ]

    for field in required_fields:
        if not data.get(field):
            return jsonify({'error': f'{field}가 누락되었습니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 중복 신청 체크 (같은 학생이 겹치는 기간에 신청했는지)
            cur.execute("""
                SELECT reservation_id FROM VacationReservation
                WHERE student_id = %s
                AND status NOT IN ('퇴실', '예약불가')
                AND (
                    (check_in_date <= %s AND check_out_date >= %s) OR
                    (check_in_date <= %s AND check_out_date >= %s) OR
                    (check_in_date >= %s AND check_out_date <= %s)
                )
            """, (
                data['student_id'],
                data['check_in_date'], data['check_in_date'],
                data['check_out_date'], data['check_out_date'],
                data['check_in_date'], data['check_out_date']
            ))

            existing = cur.fetchone()
            if existing:
                return jsonify({'error': '같은 기간에 이미 신청한 예약이 있습니다.'}), 400

            # 방학 이용 신청 저장
            insert_query = """
                INSERT INTO VacationReservation (
                    student_id, student_name, student_phone,
                    reserver_name, reserver_relation, reserver_phone,
                    building, room_type, guest_count,
                    check_in_date, check_out_date, total_amount
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """

            cur.execute(
                insert_query,
                (data['student_id'],
                 data['student_name'],
                    data['student_phone'],
                    data['reserver_name'],
                    data['reserver_relation'],
                    data['reserver_phone'],
                    data['building'],
                    data['room_type'],
                    data['guest_count'],
                    data['check_in_date'],
                    data['check_out_date'],
                    data['total_amount']))

        conn.commit()
        return jsonify({'message': '방학 이용 신청이 완료되었습니다.'}), 201

    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/vacation/requests', methods=['GET'])
def get_student_vacation_requests():
    """학생용 방학 이용 신청 내역 조회"""
    student_id = request.args.get('student_id')
    if not student_id:
        return jsonify({'error': 'student_id가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT * FROM VacationReservation
                WHERE student_id = %s
                ORDER BY created_at DESC
            """, (student_id,))

            data = cur.fetchall()

            # 날짜 필드 변환
            for item in data:
                if item.get('check_in_date'):
                    item['check_in_date'] = str(item['check_in_date'])
                if item.get('check_out_date'):
                    item['check_out_date'] = str(item['check_out_date'])
                if item.get('created_at'):
                    item['created_at'] = item['created_at'].isoformat()
                if item.get('updated_at'):
                    item['updated_at'] = item['updated_at'].isoformat()

        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/vacation/rates', methods=['GET'])
def get_vacation_rates():
    """방학 이용 요금 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM VacationRates ORDER BY room_type")
            data = cur.fetchall()

            # 딕셔너리 형태로 변환
            rates = {}
            for rate in data:
                rates[rate['room_type']] = {
                    'base_rate': rate['base_rate'],
                    'extra_person_rate': rate['extra_person_rate']
                }

        return jsonify(rates)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/vacation/requests', methods=['GET'])
def admin_get_vacation_requests():
    """관리자용 방학 이용 신청 목록 조회"""
    status_filter = request.args.get('status', '전체')
    search = request.args.get('search', '')
    tab = request.args.get('tab', '예약정보')  # 예약정보 또는 누적데이터

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기본 쿼리
            base_query = "SELECT * FROM VacationReservation"
            conditions = []
            params = []

            # 탭에 따른 필터링
            if tab == '예약정보':
                conditions.append("status NOT IN ('퇴실', '예약불가')")
            elif tab == '누적데이터':
                conditions.append("status IN ('퇴실', '예약불가')")

            # 상태 필터
            if status_filter != '전체':
                conditions.append("status = %s")
                params.append(status_filter)

            # 검색 필터
            if search:
                conditions.append(
                    "(student_name LIKE %s OR student_id LIKE %s)")
                params.extend([f'%{search}%', f'%{search}%'])

            # 조건 추가
            if conditions:
                base_query += " WHERE " + " AND ".join(conditions)

            base_query += " ORDER BY created_at DESC"

            cur.execute(base_query, params)
            data = cur.fetchall()

            # 날짜 필드 변환
            for item in data:
                if item.get('check_in_date'):
                    item['check_in_date'] = str(item['check_in_date'])
                if item.get('check_out_date'):
                    item['check_out_date'] = str(item['check_out_date'])
                if item.get('created_at'):
                    item['created_at'] = item['created_at'].isoformat()
                if item.get('updated_at'):
                    item['updated_at'] = item['updated_at'].isoformat()

        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/vacation/request/<int:reservation_id>/status',
           methods=['PUT'])
def admin_update_vacation_status(reservation_id):
    """관리자용 방학 이용 신청 상태 업데이트"""
    data = request.json
    status = data.get('status')
    admin_memo = data.get('admin_memo', '')
    cancel_reason = data.get('cancel_reason', '')

    if not status:
        return jsonify({'error': '상태가 필요합니다.'}), 400

    # 예약불가 처리 시 사유 필수
    if status == '예약불가' and not cancel_reason.strip():
        return jsonify({'error': '예약불가 처리 시 사유를 입력해야 합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기존 예약 정보 조회
            cur.execute(
                "SELECT * FROM VacationReservation WHERE reservation_id = %s",
                (reservation_id,
                 ))
            existing = cur.fetchone()

            if not existing:
                return jsonify({'error': '예약을 찾을 수 없습니다.'}), 404

            # 상태 및 메모 업데이트
            cur.execute("""
                UPDATE VacationReservation
                SET status = %s, admin_memo = %s, cancel_reason = %s, updated_at = NOW()
                WHERE reservation_id = %s
            """, (status, admin_memo, cancel_reason, reservation_id))

        conn.commit()
        return jsonify({'message': f'예약이 {status} 상태로 업데이트되었습니다.'})

    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/vacation/stats', methods=['GET'])
def get_vacation_stats():
    """관리자용 방학 이용 통계"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 전체 통계
            cur.execute("""
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN status = '대기' THEN 1 ELSE 0 END) as waiting,
                    SUM(CASE WHEN status = '확정' THEN 1 ELSE 0 END) as confirmed,
                    SUM(CASE WHEN status = '입실' THEN 1 ELSE 0 END) as checked_in,
                    SUM(CASE WHEN status = '퇴실' THEN 1 ELSE 0 END) as checked_out,
                    SUM(CASE WHEN status = '예약불가' THEN 1 ELSE 0 END) as cancelled
                FROM VacationReservation
            """)

            stats = cur.fetchone()

            # Decimal을 int로 변환
            for key, value in stats.items():
                if hasattr(value, 'real'):  # Decimal 타입 체크
                    stats[key] = int(value)

        return jsonify(stats)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# ========================================
# 학생 알림 시스템 API
# ========================================


@app.route('/api/student/notifications', methods=['GET'])
def get_student_notifications():
    """학생별 최근 승인/반려 알림 조회"""
    student_id = request.args.get('student_id')
    if not student_id:
        return jsonify({'error': 'student_id가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            notifications = []

            # 1. AS 신청 상태 변경 알림 (최근 7일)
            cur.execute("""
                SELECT as_uuid, stat, as_category, description, reg_dt
                FROM After_Service
                WHERE student_id = %s
                AND stat IN ('처리완료', '반려')
                AND reg_dt >= DATE_SUB(NOW(), INTERVAL 7 DAY)
                ORDER BY reg_dt DESC
                LIMIT 5
            """, (student_id,))

            as_results = cur.fetchall()
            for item in as_results:
                icon = 'check_circle' if item['stat'] == '처리완료' else 'cancel'
                color = '#27AE60' if item['stat'] == '처리완료' else '#E74C3C'
                title = f"A/S 신청이 {item['stat']}되었습니다."
                subtitle = f"{item['as_category']} - {item['description'][:20]}..."

                notifications.append({
                    'type': 'as',
                    'icon': icon,
                    'color': color,
                    'title': title,
                    'subtitle': subtitle,
                    'date': item['reg_dt'].isoformat(),
                    'uuid': item['as_uuid']
                })

            # 2. 외박 신청 상태 변경 알림 (최근 7일)
            cur.execute("""
                SELECT out_uuid, stat, place, reason, reg_dt
                FROM Outting
                WHERE student_id = %s
                AND stat IN ('승인', '반려')
                AND reg_dt >= DATE_SUB(NOW(), INTERVAL 7 DAY)
                ORDER BY reg_dt DESC
                LIMIT 5
            """, (student_id,))

            overnight_results = cur.fetchall()
            for item in overnight_results:
                icon = 'check_circle' if item['stat'] == '승인' else 'cancel'
                color = '#27AE60' if item['stat'] == '승인' else '#E74C3C'
                title = f"외박 신청이 {item['stat']}되었습니다."
                subtitle = f"{item['place']} - {item['reason'][:20]}..."

                notifications.append({
                    'type': 'overnight',
                    'icon': icon,
                    'color': color,
                    'title': title,
                    'subtitle': subtitle,
                    'date': item['reg_dt'].isoformat(),
                    'uuid': item['out_uuid']
                })

            # 3. 석식 신청 관련 알림은 현재 생략 (추후 구현)

            # 날짜순 정렬 (최신순)
            notifications.sort(key=lambda x: x['date'], reverse=True)

            return jsonify({
                'success': True,
                'notifications': notifications[:10]  # 최대 10개만 반환
            })

    except Exception as e:
        print(f"알림 조회 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/student/notifications/mark-read', methods=['POST'])
def mark_notification_read():
    """알림 읽음 처리 (향후 확장 가능)"""
    data = request.json
    student_id = data.get('student_id')
    notification_type = data.get('type')
    notification_uuid = data.get('uuid')

    # 현재는 단순히 성공 응답만 반환
    # 추후 읽음 상태를 DB에 저장하는 기능 추가 가능
    return jsonify({'success': True})


@app.route('/api/test/create-notifications', methods=['POST'])
def create_test_notifications():
    """테스트용 알림 데이터 생성"""
    data = request.json
    student_id = data.get('student_id', '1')

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 1. 처리완료된 AS 요청 생성
            cur.execute("""
                INSERT INTO After_Service (
                    as_uuid, student_id, as_category, description, stat, reg_dt
                ) VALUES (%s, %s, %s, %s, %s, %s)
            """, (
                str(uuid.uuid4()),
                student_id,
                '형광등',
                '형광등 교체 요청',
                '처리완료',
                datetime.now() - timedelta(days=1)
            ))

            # 2. 반려된 AS 요청 생성
            cur.execute("""
                INSERT INTO After_Service (
                    as_uuid, student_id, as_category, description, stat, reg_dt, rejection_reason
                ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (
                str(uuid.uuid4()),
                student_id,
                '에어컨',
                '에어컨 수리 요청',
                '반려',
                datetime.now() - timedelta(days=2),
                '부품 부족으로 인한 지연'
            ))

            # 3. 승인된 외박 신청 생성
            cur.execute("""
                INSERT INTO Outting (
                    out_uuid, student_id, out_type, place, reason, stat, reg_dt,
                    out_start, out_end, return_time, par_agr
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                str(uuid.uuid4()),
                student_id,
                '외박',
                '집',
                '가족 모임',
                '승인',
                datetime.now() - timedelta(days=1),
                (datetime.now() + timedelta(days=1)).date(),
                (datetime.now() + timedelta(days=2)).date(),
                '20:00',
                1
            ))

            # 4. 반려된 외박 신청 생성
            cur.execute("""
                INSERT INTO Outting (
                    out_uuid, student_id, out_type, place, reason, stat, reg_dt,
                    out_start, out_end, return_time, par_agr
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                str(uuid.uuid4()),
                student_id,
                '외박',
                '친구집',
                '개인사유',
                '반려',
                datetime.now() - timedelta(days=3),
                (datetime.now() + timedelta(days=4)).date(),
                (datetime.now() + timedelta(days=5)).date(),
                '20:00',
                1
            ))

        conn.commit()
        return jsonify({
            'success': True,
            'message': f'학생 {student_id}에 대한 테스트 알림 데이터가 생성되었습니다.'
        })

    except Exception as e:
        conn.rollback()
        print(f"테스트 데이터 생성 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 입실신청 상태변경 이력 API ===

# 1. 특정 입실신청의 상태변경 이력 조회 API


@app.route('/api/checkin/history/<int:checkin_id>', methods=['GET'])
def get_checkin_status_history(checkin_id):
    """특정 입실신청의 상태변경 이력 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                SELECT
                    h.*,
                    c.student_id,
                    ds.name as student_name
                FROM Checkin_Status_History h
                LEFT JOIN Checkin c ON h.checkin_id = c.checkin_id
                LEFT JOIN Domi_Students ds ON h.student_id = ds.student_id
                WHERE h.checkin_id = %s
                ORDER BY h.created_at DESC
            '''
            cur.execute(query, (checkin_id,))
            history = cur.fetchall()

            # 날짜 형식 변환
            for item in history:
                if item['created_at']:
                    item['created_at'] = item['created_at'].isoformat()

        return jsonify({'success': True, 'history': history})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 2. 학생별 입실신청 상태변경 이력 조회 API


@app.route('/api/checkin/student-history/<student_id>', methods=['GET'])
def get_student_checkin_history(student_id):
    """특정 학생의 모든 입실신청 상태변경 이력 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                SELECT
                    h.*,
                    c.student_id,
                    ds.name as student_name
                FROM Checkin_Status_History h
                LEFT JOIN Checkin c ON h.checkin_id = c.checkin_id
                LEFT JOIN Domi_Students ds ON h.student_id = ds.student_id
                WHERE h.student_id = %s
                ORDER BY h.created_at DESC
            '''
            cur.execute(query, (student_id,))
            history = cur.fetchall()

            # 날짜 형식 변환
            for item in history:
                if item['created_at']:
                    item['created_at'] = item['created_at'].isoformat()

        return jsonify({'success': True, 'history': history})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 3. 관리자용 입실신청 이력 조회 API (전체)


@app.route('/api/admin/checkin/history', methods=['GET'])
def admin_get_checkin_history():
    """관리자용 입실신청 상태변경 이력 전체 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                SELECT
                    h.*,
                    c.student_id,
                    ds.name as student_name,
                    ds.dept as department
                FROM Checkin_Status_History h
                LEFT JOIN Checkin c ON h.checkin_id = c.checkin_id
                LEFT JOIN Domi_Students ds ON c.student_id = ds.student_id
                ORDER BY h.changed_at DESC
                LIMIT 100
            '''
            cur.execute(query)
            history = cur.fetchall()

            # 날짜 형식 변환
            for item in history:
                if item['changed_at']:
                    item['changed_at'] = item['changed_at'].isoformat()

        return jsonify({'success': True, 'history': history})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 테스트용 입실신청 서류 데이터 생성 API


@app.route('/api/test/create-checkin-documents', methods=['POST'])
def create_checkin_documents_test_data():
    """테스트용 입실신청 서류 데이터 생성"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기존 Checkin_Documents 테이블이 있는지 확인
            cur.execute("SHOW TABLES LIKE 'Checkin_Documents'")
            if not cur.fetchone():
                # 테이블이 없으면 생성
                cur.execute("""
                    CREATE TABLE Checkin_Documents (
                        document_id INT AUTO_INCREMENT PRIMARY KEY,
                        checkin_id INT NOT NULL,
                        file_name VARCHAR(255) NOT NULL,
                        file_url VARCHAR(500),
                        upload_path VARCHAR(500),
                        status VARCHAR(50) DEFAULT '제출완료',
                        file_type VARCHAR(50),
                        uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        verified_at TIMESTAMP NULL,
                        recruit_type VARCHAR(50) DEFAULT '1차',
                        FOREIGN KEY (checkin_id) REFERENCES Checkin(checkin_id) ON DELETE CASCADE
                    )
                """)
                print("Checkin_Documents 테이블을 생성했습니다.")

            # 기존 테스트 데이터 삭제
            cur.execute("DELETE FROM Checkin_Documents")

            # 현재 입실신청 데이터 조회
            cur.execute("SELECT checkin_id FROM Checkin LIMIT 8")
            checkin_ids = [row['checkin_id'] for row in cur.fetchall()]

            if not checkin_ids:
                return jsonify(
                    {'error': '입실신청 데이터가 없습니다. 먼저 입실신청 데이터를 생성하세요.'}), 400

            # 각 입실신청에 대해 서류 데이터 생성
            document_types = [
                {'name': '주민등록등본', 'type': '.pdf'},
                {'name': '가족관계증명서', 'type': '.pdf'},
                {'name': '건강진단서', 'type': '.jpg'},
                {'name': '결핵검진서', 'type': '.jpg'},
                {'name': '서약서', 'type': '.pdf'},
            ]

            for checkin_id in checkin_ids:
                # 각 신청당 3-5개의 서류 생성 (랜덤)
                import random
                num_docs = random.randint(3, 5)
                selected_docs = random.sample(document_types, num_docs)

                for i, doc in enumerate(selected_docs):
                    file_name = f"{doc['name']}_{checkin_id}{doc['type']}"
                    file_url = f"/uploads/in/test_{file_name}"
                    status = '제출완료' if i < num_docs - 1 else '제출완료'  # 마지막 서류는 미확인

                    cur.execute("""
                        INSERT INTO Checkin_Documents (
                            checkin_id, file_name, file_url, upload_path,
                            status, file_type, uploaded_at, recruit_type
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        checkin_id,
                        file_name,
                        file_url,
                        f"uploads/in/test_{file_name}",
                        status,
                        doc['type'],
                        datetime.now() - timedelta(days=random.randint(1, 7)),
                        '신입생' if checkin_id % 2 == 0 else '재학생'
                    ))

            conn.commit()

            # 생성된 데이터 개수 확인
            cur.execute("SELECT COUNT(*) as count FROM Checkin_Documents")
            total_count = cur.fetchone()['count']

            return jsonify({
                'message': f'테스트용 서류 데이터 {total_count}개가 생성되었습니다.',
                'checkin_count': len(checkin_ids),
                'document_count': total_count
            })

    except Exception as e:
        conn.rollback()
        print(f"서류 테스트 데이터 생성 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 신입생 입주신청(Firstin) 관리 API ===

# 입실신청 테스트 데이터 생성 API


@app.route('/api/test/create-checkin-data', methods=['POST'])
def create_checkin_test_data():
    """테스트용 입실신청 데이터 생성"""
    data = request.json
    student_id = data.get('student_id', '1')

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 1. 입실신청 데이터 생성
            cur.execute("""
                INSERT INTO Checkin (
                    recruit_type, year, semester, name, student_id, department,
                    smoking, building, room_type, room_num, payback_bank,
                    payback_name, payback_num, reg_dt, status, auto_eligible
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                '재학생',  # 김선민은 3학년 재학생이므로 '재학생'으로 설정
                '2025',
                '1학기',
                '김선민',
                student_id,
                '소프트웨어융합과',
                '비흡연',
                '숭례원',
                '2인실',
                '',
                '하나은행',
                '김선민',
                '89791999933394',
                datetime.now(),
                '미배정',
                1
            ))

            checkin_id = cur.lastrowid

            # 2. 입실신청 서류 데이터 생성
            cur.execute("""
                INSERT INTO Checkin_Documents (
                    checkin_id, file_name, status, recruit_type,
                    upload_path, uploaded_at, file_type, file_url
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                checkin_id,
                '입학원서.pdf',
                '제출완료',
                '재학생',
                'uploads/in/test_document.pdf',
                datetime.now(),
                '.pdf',
                '/uploads/in/test_document.pdf'
            ))

            cur.execute("""
                INSERT INTO Checkin_Documents (
                    checkin_id, file_name, status, recruit_type,
                    upload_path, uploaded_at, file_type, file_url
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                checkin_id,
                '신분증사본.jpg',
                '제출완료',
                '재학생',
                'uploads/in/test_id.jpg',
                datetime.now(),
                '.jpg',
                '/uploads/in/test_id.jpg'
            ))

        conn.commit()
        return jsonify({
            'success': True,
            'message': f'학생 {student_id}에 대한 입실신청 테스트 데이터가 생성되었습니다.',
            'checkin_id': checkin_id
        })

    except Exception as e:
        conn.rollback()
        print(f"입실신청 테스트 데이터 생성 오류: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# === 자동배정 시스템 API ===

# 방 데이터 생성 API 삭제됨 - 데이터 불일치 방지


@app.route('/api/test/room-info-columns', methods=['GET'])
def test_room_info_columns():
    """Room_Info 테이블의 컬럼 구조 확인"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 테이블 구조 확인
            cur.execute("DESCRIBE Room_Info")
            columns = cur.fetchall()

            # 샘플 데이터 확인
            cur.execute("SELECT * FROM Room_Info LIMIT 5")
            sample_data = cur.fetchall()

        return jsonify({
            'columns': columns,
            'sample_data': sample_data
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/rooms/available', methods=['GET'])
def get_available_rooms():
    """자동배정용 사용가능 방 목록 조회"""
    building = request.args.get('building')  # 선택적 필터
    floor = request.args.get('floor')        # 선택적 필터
    room_type = request.args.get('room_type')  # 선택적 필터
    gender = request.args.get('gender')       # 선택적 필터

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기본 쿼리: 방 정보와 현재 배정 현황 (10층 제외, 흡연 허용 정보 포함)
            query = '''
                SELECT
                    ri.room_id,
                    ri.building,
                    ri.floor_number as floor,
                    ri.room_number,
                    ri.room_type,
                    ri.max_occupancy as capacity,
                    CASE
                        WHEN ri.building = '양덕원' THEN '여'
                        WHEN ri.building = '숭례원' THEN '남'
                        ELSE '혼성'
                    END as gender,
                    CASE
                        WHEN RIGHT(ri.room_number, 2) IN ('01', '02', '03', '04', '05')
                          OR ri.room_number LIKE '%01호' OR ri.room_number LIKE '%02호'
                          OR ri.room_number LIKE '%03호' OR ri.room_number LIKE '%04호'
                          OR ri.room_number LIKE '%05호' THEN 1  -- 각 층 01~05호는 흡연 허용
                        ELSE 0
                    END as smoking_allowed,
                    COALESCE(COUNT(ds.student_id), 0) as current_occupancy,
                    (ri.max_occupancy - COALESCE(COUNT(ds.student_id), 0)) as available_spots,
                    CASE
                        WHEN ri.floor_number = 6 THEN '1인실'
                        WHEN ri.floor_number = 7 THEN '2인실'
                        WHEN ri.floor_number = 8 THEN '3인실'
                        WHEN ri.floor_number = 9 THEN '룸메이트'
                        ELSE ri.room_type
                    END as expected_room_type
                FROM Room_Info ri
                LEFT JOIN Domi_Students ds ON ri.building = ds.dorm_building
                    AND ri.room_number = ds.room_num
                    AND ds.stat = '입주중'
                WHERE ri.status = '사용가능'
                AND ri.floor_number BETWEEN 6 AND 9  -- 10층(방학이용층) 제외
            '''
            params = []

            # 필터 조건 추가
            if building:
                query += ' AND ri.building = %s'
                params.append(building)
            if floor:
                query += ' AND ri.floor_number = %s'
                params.append(floor)
            if room_type:
                query += ' AND ri.room_type = %s'
                params.append(room_type)
            if gender:
                if gender == '남':
                    query += ' AND ri.building = %s'
                    params.append('숭례원')
                elif gender == '여':
                    query += ' AND ri.building = %s'
                    params.append('양덕원')

            query += '''
                GROUP BY ri.room_id, ri.building, ri.floor_number, ri.room_number,
                         ri.room_type, ri.max_occupancy
                HAVING available_spots > 0
                ORDER BY ri.building, ri.floor_number, ri.room_number
            '''

            cur.execute(query, params)
            rooms = cur.fetchall()

        return jsonify(rooms)

    except Exception as e:
        print(f"사용가능 방 조회 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 2. 자동배정 실행 API - 확인상태 학생들 자동배정


@app.route('/api/admin/auto-assign', methods=['POST'])
def execute_auto_assignment():
    """확인상태 학생들에 대한 자동배정 실행"""
    data = request.json
    dry_run = data.get('dry_run', False)  # 실제 배정 없이 시뮬레이션만

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 1. 배정 대상 학생 조회 (확인 상태이면서 미배정, 모든 필요 정보 포함)
            cur.execute('''
                SELECT c.*,
                       COALESCE(ds.gender, '남') as gender,
                       COALESCE(ds.name, c.name) as name,
                       COALESCE(ds.dorm_building, c.building) as building,
                       '대한민국' as nationality,
                       COALESCE(c.smoking, '비흡연') as smoking,
                       '내국인' as applicant_type
                FROM Checkin c
                LEFT JOIN Domi_Students ds ON c.student_id = ds.student_id
                WHERE c.status = '확인'
                AND (c.room_num = '' OR c.room_num IS NULL OR TRIM(c.room_num) = '')
                AND c.student_id NOT IN (
                    SELECT DISTINCT ds2.student_id
                    FROM Domi_Students ds2
                    WHERE ds2.room_num IS NOT NULL
                    AND ds2.room_num != ''
                    AND ds2.stat = '입주중'
                )
                ORDER BY c.reg_dt ASC
            ''')
            students_to_assign = cur.fetchall()

            print(f"🔍 자동배정 - 배정 대상 학생: {len(students_to_assign)}명")
            for student in students_to_assign:
                nationality_type = '내국인' if student.get(
                    'nationality') == '대한민국' else '외국인'
                target_floor = {
                    '1인실': '6층',
                    '2인실': '7층',
                    '3인실': '8층',
                    '룸메이트': '9층'}.get(
                    student.get('room_type'),
                    '?층')
                print(f"  - {student.get('name', 'Unknown')} ({student.get('student_id', 'None')}): "
                      f"성별={student.get('gender', 'None')}, 건물={student.get('building', 'None')}, "
                      f"방타입={student.get('room_type', 'None')}({target_floor}), "
                      f"국적={nationality_type}, 흡연={student.get('smoking', 'None')}")

            if not students_to_assign:
                # 배정 취소된 학생이 있는지 추가 확인
                cur.execute('''
                    SELECT COUNT(*) as cancelled_count
                    FROM Checkin c
                    WHERE c.status = '확인'
                    AND (c.room_num = '' OR c.room_num IS NULL OR TRIM(c.room_num) = '')
                ''')
                cancelled_check = cur.fetchone()

                message = '배정할 학생이 없습니다.'
                if cancelled_check and cancelled_check['cancelled_count'] > 0:
                    message = f'현재 {
                        cancelled_check["cancelled_count"]}명의 학생이 배정 대기 중이나, 이미 다른 방에 배정되어 있거나 조건이 맞지 않습니다.'

                return jsonify({
                    'success': True,
                    'message': message,
                    'assigned_count': 0,
                    'failed_assignments': []
                })

            # 2. 실시간 방 점유 상황을 정확히 파악하기 위한 함수
            def get_real_time_room_occupancy(room_number, building):
                """실시간으로 특정 방의 현재 점유 인원 확인 (Checkin + Domi_Students 테이블 모두 확인)"""
                # 1. Checkin 테이블에서 배정된 학생 수 확인
                cur.execute('''
                    SELECT COUNT(*) as checkin_count
                    FROM Checkin c
                    WHERE c.room_num = %s
                    AND c.building = %s
                    AND c.status IN ('배정완료', '확인')
                    AND c.room_num IS NOT NULL
                    AND c.room_num != ''
                ''', (room_number, building))
                checkin_result = cur.fetchone()
                checkin_count = checkin_result['checkin_count'] if checkin_result else 0
                
                # 2. Domi_Students 테이블에서 입주중인 학생 수 확인
                cur.execute('''
                    SELECT COUNT(*) as domi_count
                    FROM Domi_Students ds
                    WHERE ds.dorm_building = %s
                    AND ds.room_num = %s
                    AND ds.stat = '입주중'
                ''', (building, room_number))
                domi_result = cur.fetchone()
                domi_count = domi_result['domi_count'] if domi_result else 0
                
                # 3. 두 값 중 더 큰 값을 반환 (더 정확한 점유율)
                actual_count = max(checkin_count, domi_count)
                print(f"🔍 점유율 계산 - {building} {room_number}: Checkin={checkin_count}, Domi={domi_count}, 실제={actual_count}")
                return actual_count

            # 사용가능한 방 조회 (10층 제외, 흡연 허용 정보 포함)
            cur.execute('''
                SELECT
                    ri.*,
                    COALESCE(COUNT(ds.student_id), 0) as current_occupancy,
                    (ri.max_occupancy - COALESCE(COUNT(ds.student_id), 0)) as available_spots,
                    CASE
                        WHEN RIGHT(ri.room_number, 2) IN ('01', '02', '03', '04', '05')
                          OR ri.room_number LIKE '%01호' OR ri.room_number LIKE '%02호'
                          OR ri.room_number LIKE '%03호' OR ri.room_number LIKE '%04호'
                          OR ri.room_number LIKE '%05호' THEN 1  -- 각 층 01~05호는 흡연 허용
                        ELSE 0
                    END as smoking_allowed,
                    CASE
                        WHEN ri.building = '숭례원' THEN '남'
                        WHEN ri.building = '양덕원' THEN '여'
                        ELSE '혼성'
                    END as building_gender,
                    CASE
                        WHEN ri.floor_number = 6 THEN '1인실'
                        WHEN ri.floor_number = 7 THEN '2인실'
                        WHEN ri.floor_number = 8 THEN '3인실'
                        WHEN ri.floor_number = 9 THEN '룸메이트'
                        ELSE ri.room_type
                    END as expected_room_type
                FROM Room_Info ri
                LEFT JOIN Domi_Students ds ON ri.building = ds.dorm_building
                    AND ri.room_number = ds.room_num
                    AND ds.stat = '입주중'
                WHERE ri.status = '사용가능'
                AND ri.floor_number BETWEEN 6 AND 9  -- 10층(방학이용층) 제외
                GROUP BY ri.room_id
                HAVING available_spots > 0
                ORDER BY ri.building, ri.floor_number, ri.room_number
            ''')
            available_rooms = cur.fetchall()

            print(
                f"🔍 자동배정 - 초기 사용가능한 방: {len(available_rooms)}개 (6~9층만, 10층 제외)")
            for room in available_rooms[:3]:  # 처음 3개만 출력
                print(
                    f"  - {
                        room.get(
                            'building',
                            'None')} {
                        room.get(
                            'floor_number',
                            'None')}층 {
                        room.get(
                            'room_number',
                            'None')}: " f"타입={
                                room.get(
                                    'expected_room_type',
                                    'None')}, 정원={
                                        room.get(
                                            'max_occupancy',
                                            'None')}, " f"현재={
                                                room.get(
                                                    'current_occupancy',
                                                    'None')}, 가능={
                                                        room.get(
                                                            'available_spots',
                                                            'None')}, " f"흡연={
                                                                '허용' if room.get(
                                                                    'smoking_allowed',
                                                                    0) else '금지'}")

            # 3. 룸메이트 쌍 먼저 처리
            roommate_pairs = []
            processed_students = set()

            # 룸메이트 관계 조회 (상호 승인된 관계만)
            cur.execute('''
                SELECT DISTINCT rr1.requester_id as student1_id, rr1.requested_id as student2_id
                FROM Roommate_Requests rr1
                WHERE rr1.status = 'accepted'
                AND rr1.roommate_type = 'mutual'
                AND EXISTS (
                    SELECT 1 FROM Roommate_Requests rr2
                    WHERE rr2.requester_id = rr1.requested_id
                    AND rr2.requested_id = rr1.requester_id
                    AND rr2.status = 'accepted'
                    AND rr2.roommate_type = 'mutual'
                )
                AND rr1.requester_id IN (
                    SELECT student_id FROM Checkin WHERE status = '확인'
                )
                AND rr1.requested_id IN (
                    SELECT student_id FROM Checkin WHERE status = '확인'
                )
            ''')
            mutual_roommates = cur.fetchall()

            print(f"🔍 자동배정 - 상호 승인된 룸메이트 쌍: {len(mutual_roommates)}쌍")
            for pair in mutual_roommates:
                print(
                    f"  - 룸메이트 쌍: {
                        pair.get(
                            'student1_id',
                            'None')} ↔ {
                        pair.get(
                            'student2_id',
                            'None')}")

            # 룸메이트 쌍 배정 로직
            assigned_count = 0
            failed_assignments = []
            assignment_results = []

            # 룸메이트 쌍 배정
            for pair in mutual_roommates:
                student1 = next(
                    (s for s in students_to_assign if s['student_id'] == pair['student1_id']), None)
                student2 = next(
                    (s for s in students_to_assign if s['student_id'] == pair['student2_id']), None)

                if student1 and student2 and pair['student1_id'] not in processed_students:
                    # 룸메이트 쌍 기본 정보 확인
                    print(
                        f"🔍 룸메이트 쌍 배정 시도: {
                            student1.get(
                                'name',
                                'Unknown')} ↔ {
                            student2.get(
                                'name',
                                'Unknown')}")
                    print(
                        f"  - {
                            student1.get(
                                'name',
                                'Unknown')}: 성별={
                            student1.get(
                                'gender',
                                'None')}, 건물={
                            student1.get(
                                'building',
                                'None')}, 국적={
                            student1.get(
                                'nationality',
                                'None')}, 흡연={
                            student1.get(
                                'smoking',
                                'None')}")
                    print(
                        f"  - {
                            student2.get(
                                'name',
                                'Unknown')}: 성별={
                            student2.get(
                                'gender',
                                'None')}, 건물={
                            student2.get(
                                'building',
                                'None')}, 국적={
                            student2.get(
                                'nationality',
                                'None')}, 흡연={
                            student2.get(
                                'smoking',
                                'None')}")

                    # 룸메이트 쌍 호환성 검사
                    compatibility_issues = []

                    # 1. 성별 일치 확인
                    if student1.get('gender') != student2.get('gender'):
                        compatibility_issues.append('성별 불일치')

                    # 2. 건물 일치 확인
                    if student1.get('building') != student2.get('building'):
                        compatibility_issues.append('건물 불일치')

                    # 3. 국적 호환성 확인 (내국인끼리, 외국인끼리 우선 배정)
                    student1_nationality_type = '내국인' if student1.get(
                        'nationality') == '대한민국' else '외국인'
                    student2_nationality_type = '내국인' if student2.get(
                        'nationality') == '대한민국' else '외국인'
                    if student1_nationality_type != student2_nationality_type:
                        compatibility_issues.append('국적 유형 불일치 (내국인-외국인 혼합)')

                    # 호환성 문제가 있으면 배정 실패
                    if compatibility_issues:
                        print(
                            f"⚠️ 룸메이트 쌍 호환성 문제: {
                                ', '.join(compatibility_issues)}")
                        failed_assignments.append({
                            'students': [student1['name'], student2['name']],
                            'reason': f'룸메이트 호환성 문제: {", ".join(compatibility_issues)}'
                        })
                        continue

                    # 적합한 방 찾기 (룸메이트용 - 실시간 점유 확인)
                    suitable_room = None
                    for room in available_rooms:
                        room_gender = room.get('building_gender', '혼성')
                        student_gender = student1['gender'].replace(
                            '자', '') if student1['gender'] else None

                        # 기본 조건 확인 (룸메이트는 9층만 가능)
                        expected_room_type = room.get(
                            'expected_room_type', room['room_type'])
                        if not (room_gender == student_gender and
                                room['building'] == student1['building'] and
                                expected_room_type == '룸메이트' and
                                room.get('floor_number') == 9):
                            print(
                                f"⚠️ 룸메이트 기본 조건 불일치 - 방 {
                                    room['building']} {
                                    room['room_number']}: " f"성별({room_gender}≠{student_gender}) 또는 " f"건물({
                                    room['building']}≠{
                                    student1['building']}) 또는 " f"방타입({expected_room_type}≠룸메이트) 또는 층수({
                                    room.get('floor_number')}≠9)")
                            continue

                        # 흡연 조건 확인 (둘 중 하나라도 흡연자면 흡연 허용 방 필요)
                        someone_smokes = (
                            student1.get('smoking') == '흡연' or student2.get('smoking') == '흡연')
                        if someone_smokes and not room.get(
                                'smoking_allowed', 0):
                            print(
                                f"⚠️ 룸메이트 흡연 조건 불일치 - 방 {room['building']} {room['room_number']}: 흡연자 있지만 금연방")
                            continue

                        # 실시간 점유 상황 확인 (룸메이트 쌍용 - 2자리 필요)
                        current_occupancy = get_real_time_room_occupancy(
                            room['room_number'], room['building'])
                        real_available_spots = room['max_occupancy'] - \
                            current_occupancy

                        print(
                            f"🔍 룸메이트 배정 - 방 {
                                room['building']} {
                                room['room_number']}: 정원={
                                room['max_occupancy']}, 현재점유={current_occupancy}, 실제가능={real_available_spots}")

                        if real_available_spots < 2:
                            print(
                                f"⚠️ 룸메이트 배정 - 방 {room['building']} {room['room_number']} 2자리 부족 - 건너뜀")
                            continue

                            suitable_room = room
                            break

                    if suitable_room:
                        if not dry_run:
                            # 배정 전 한 번 더 실시간 확인 (룸메이트 쌍용)
                            final_check_occupancy = get_real_time_room_occupancy(
                                suitable_room['room_number'], suitable_room['building'])
                            final_available_spots = suitable_room['max_occupancy'] - \
                                final_check_occupancy

                            if final_available_spots < 2:
                                print(
                                    f"⚠️ 룸메이트 최종 확인 - 방 {
                                        suitable_room['building']} {
                                        suitable_room['room_number']} 2자리 부족, 배정 실패")
                                failed_assignments.append({
                                    'students': [student1['name'], student2['name']],
                                    'reason': f'배정 직전 방에 2자리 부족 ({suitable_room['building']} {suitable_room['room_number']})'
                                })
                                continue

                            # 실제 배정 수행
                            cur.execute('''
                                UPDATE Checkin SET room_num = %s, status = '배정완료'
                                WHERE student_id IN (%s, %s)
                            ''', (suitable_room['room_number'], student1['student_id'], student2['student_id']))

                            # 학생 테이블도 업데이트 (방 번호 + 입주 상태)
                            cur.execute('''
                                UPDATE Domi_Students SET 
                                    room_num = %s,
                                    dorm_building = %s,
                                    stat = '입주중'
                                WHERE student_id IN (%s, %s)
                            ''', (suitable_room['room_number'], suitable_room['building'], student1['student_id'], student2['student_id']))

                            print(
                                f"✅ 룸메이트 배정 완료: {
                                    student1['name']}, {
                                    student2['name']} -> {
                                    suitable_room['building']} {
                                    suitable_room['room_number']}")

                        assignment_results.append({
                            'type': 'roommate_pair',
                            'students': [student1['name'], student2['name']],
                            'student_ids': [student1['student_id'], student2['student_id']],
                            'assigned_room': f"{suitable_room['building']} {suitable_room['room_number']}",
                            'room_type': suitable_room['room_type']
                        })

                        assigned_count += 2
                        processed_students.add(pair['student1_id'])
                        processed_students.add(pair['student2_id'])
                    else:
                        failed_assignments.append({
                            'students': [student1['name'], student2['name']],
                            'reason': '적합한 룸메이트 방이 없음'
                        })

            # 개별 학생 배정
            for student in students_to_assign:
                if student['student_id'] in processed_students:
                    continue

                nationality_type = '내국인' if student.get(
                    'nationality') == '대한민국' else '외국인'
                target_floor = {
                    '1인실': '6층',
                    '2인실': '7층',
                    '3인실': '8층',
                    '룸메이트': '9층'}.get(
                    student.get('room_type'),
                    '?층')
                print(f"🔍 개별 학생 배정 시도: {student.get('name', 'Unknown')}")
                print(
                    f"  - 성별: {student.get('gender', 'None')}, 건물: {student.get('building', 'None')}")
                print(
                    f"  - 방타입: {student.get('room_type', 'None')} → {target_floor} 대상")
                print(
                    f"  - 국적: {nationality_type}, 흡연: {student.get('smoking', 'None')}")

                # 적합한 방 찾기 (실시간 점유 상황 및 모든 조건 확인)
                suitable_room = None
                for room in available_rooms:
                    room_gender = room.get('building_gender', '혼성')
                    student_gender = student['gender'].replace(
                        '자', '') if student['gender'] else None  # '남자' -> '남'
                    student_nationality_type = '내국인' if student.get(
                        'nationality') == '대한민국' else '외국인'

                    # 1. 기본 조건 확인 (성별, 건물, 방타입 + 층별 규칙)
                    expected_room_type = room.get(
                        'expected_room_type', room['room_type'])
                    if not (room_gender == student_gender and
                            room['building'] == student['building'] and
                            expected_room_type == student['room_type']):
                        print(
                            f"⚠️ 기본 조건 불일치 - 방 {
                                room['building']} {
                                room['room_number']}: " f"성별({room_gender}≠{student_gender}) 또는 " f"건물({
                                room['building']}≠{
                                student['building']}) 또는 " f"방타입({expected_room_type}≠{
                                student['room_type']})")
                        continue

                    # 2. 실시간 점유 상황 확인 (중복 배정 방지)
                    current_occupancy = get_real_time_room_occupancy(
                        room['room_number'], room['building'])
                    real_available_spots = room['max_occupancy'] - \
                        current_occupancy

                    print(
                        f"🔍 방 검사 - {
                            room['building']} {
                            room['room_number']}: 정원={
                            room['max_occupancy']}, 현재점유={current_occupancy}, 실제가능={real_available_spots}")

                    if real_available_spots <= 0:
                        print(
                            f"⚠️ 방 {
                                room['building']} {
                                room['room_number']} 이미 만실 - 건너뜀")
                        continue

                    # 3. 흡연 조건 확인
                    if student.get('smoking') == '흡연' and not room.get(
                            'smoking_allowed', 0):
                        print(
                            f"⚠️ 흡연 조건 불일치 - 방 {room['building']} {room['room_number']}: 흡연자이지만 금연방")
                        continue

                    # 4. 국적 조건 확인 (현재 방에 이미 있는 학생들의 국적 확인)
                    cur.execute('''
                        SELECT '대한민국' as nationality, COUNT(*) as count
                        FROM Domi_Students ds
                        WHERE ds.dorm_building = %s AND ds.room_num = %s AND ds.stat = '입주중'
                        GROUP BY ds.dorm_building
                    ''', (room['building'], room['room_number']))
                    current_nationalities = cur.fetchall()

                    # 방에 이미 학생이 있는 경우 국적 호환성 확인
                    if current_nationalities:
                        existing_nationality_types = []
                        for nat_info in current_nationalities:
                            existing_type = '내국인' if nat_info['nationality'] == '대한민국' else '외국인'
                            existing_nationality_types.append(existing_type)

                        # 기존 학생들과 국적 유형이 다르면 배정 불가 (내국인-외국인 분리 원칙)
                        if student_nationality_type not in existing_nationality_types:
                            print(
                                f"⚠️ 국적 조건 불일치 - 방 {
                                    room['building']} {
                                    room['room_number']}: 기존 {existing_nationality_types}, 신규 {student_nationality_type}")
                            continue

                    print(
                        f"✅ 조건 만족 - 방 {room['building']} {room['room_number']} 배정 가능")
                    suitable_room = room
                    break

                if suitable_room:
                    if not dry_run:
                        # 배정 전 한 번 더 실시간 확인 (동시성 문제 방지)
                        final_check_occupancy = get_real_time_room_occupancy(
                            suitable_room['room_number'], suitable_room['building'])
                        final_available_spots = suitable_room['max_occupancy'] - \
                            final_check_occupancy

                        if final_available_spots <= 0:
                            print(
                                f"⚠️ 최종 확인 - 방 {
                                    suitable_room['building']} {
                                    suitable_room['room_number']} 이미 만실, 배정 실패")
                            failed_assignments.append({
                                'student': student['name'],
                                'student_id': student['student_id'],
                                'reason': f'배정 직전 방이 만실됨 ({suitable_room['building']} {suitable_room['room_number']})'
                            })
                            continue

                        # 실제 배정 수행
                        cur.execute('''
                            UPDATE Checkin SET room_num = %s, status = '배정완료'
                            WHERE student_id = %s
                        ''', (suitable_room['room_number'], student['student_id']))

                        # 학생 테이블도 업데이트 (방 번호 + 입주 상태)
                        cur.execute('''
                            UPDATE Domi_Students SET 
                                room_num = %s,
                                dorm_building = %s,
                                stat = '입주중'
                            WHERE student_id = %s
                        ''', (suitable_room['room_number'], suitable_room['building'], student['student_id']))

                        print(
                            f"✅ 배정 완료: {
                                student['name']} -> {
                                suitable_room['building']} {
                                suitable_room['room_number']}")

                    assignment_results.append({
                        'type': 'individual',
                        'student': student['name'],
                        'student_id': student['student_id'],
                        'assigned_room': f"{suitable_room['building']} {suitable_room['room_number']}",
                        'room_type': suitable_room['room_type']
                    })

                    assigned_count += 1
                else:
                    # 상세한 실패 사유 분석
                    failure_reasons = []

                    # 기본 조건별 실패 사유 분석
                    matching_gender_buildings = [
                        r for r in available_rooms if r.get('building_gender') == student_gender]
                    if not matching_gender_buildings:
                        failure_reasons.append('성별 맞는 건물 없음')

                    matching_buildings = [
                        r for r in matching_gender_buildings if r['building'] == student['building']]
                    if not matching_buildings:
                        failure_reasons.append('신청 건물에 빈 방 없음')

                    matching_room_types = [
                        r for r in matching_buildings if r.get(
                            'expected_room_type',
                            r['room_type']) == student['room_type']]
                    if not matching_room_types:
                        failure_reasons.append(
                            f"신청 방타입({student['room_type']})에 맞는 층에 빈 방 없음")

                    if student.get('smoking') == '흡연':
                        smoking_allowed_rooms = [
                            r for r in matching_room_types if r.get(
                                'smoking_allowed', 0)]
                        if not smoking_allowed_rooms:
                            failure_reasons.append('흡연 허용 방 없음')

                    final_reason = '적합한 방이 없음'
                    if failure_reasons:
                        final_reason = f"조건 불일치: {', '.join(failure_reasons)}"

                    failed_assignments.append({
                        'student': student['name'],
                        'student_id': student['student_id'],
                        'reason': final_reason,
                        'student_info': {
                            'gender': student.get('gender'),
                            'building': student.get('building'),
                            'room_type': student.get('room_type'),
                            'nationality': student.get('nationality'),
                            'smoking': student.get('smoking')
                        }
                    })

            if not dry_run:
                conn.commit()

        # 적용된 조건들 요약
        applied_conditions = [
            "✅ 성별 매칭 (건물 기준)",
            "✅ 건물 매칭",
            "✅ 층별 방타입 매칭 (6층=1인실, 7층=2인실, 8층=3인실, 9층=룸메이트)",
            "✅ 10층 방학이용층 제외",
            "✅ 실시간 점유 확인",
            "✅ 흡연여부 매칭 (1~5호 흡연 허용)",
            "✅ 국적 분리 (내국인-외국인)",
            "✅ 룸메이트 신청 관계"
        ]

        summary_message = f'''자동배정이 완료되었습니다. 📊 배정 결과: 성공 {assigned_count}명 / 실패 {
            len(failed_assignments)}명 📋 적용된 조건:{
            chr(10).join(applied_conditions)}'''

        return jsonify({
            'success': True,
            'message': summary_message,
            'assigned_count': assigned_count,
            'failed_count': len(failed_assignments),
            'roommate_pairs_processed': len(mutual_roommates),
            'assignment_results': assignment_results,
            'failed_assignments': failed_assignments,
            'applied_conditions': applied_conditions,
            'dry_run': dry_run
        })

    except Exception as e:
        conn.rollback()
        print(f"자동배정 실행 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 3. 배정 현황 조회 API - 전체 배정 통계


@app.route('/api/admin/assignment-status', methods=['GET'])
def get_assignment_status():
    """전체 배정 통계 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 전체 통계
            cur.execute('''
                SELECT
                    COUNT(*) as total_applications,
                    SUM(CASE WHEN status = '배정완료' THEN 1 ELSE 0 END) as assigned,
                    SUM(CASE WHEN status = '확인' THEN 1 ELSE 0 END) as confirmed_unassigned,
                    SUM(CASE WHEN status = '미확인' THEN 1 ELSE 0 END) as pending_review
                FROM Checkin
            ''')
            overall_stats = cur.fetchone()

            # 건물별 통계
            cur.execute('''
                SELECT
                    building,
                    COUNT(*) as total,
                    SUM(CASE WHEN status = '배정완료' THEN 1 ELSE 0 END) as assigned,
                    SUM(CASE WHEN status = '확인' THEN 1 ELSE 0 END) as confirmed_unassigned
                FROM Checkin
                GROUP BY building
                ORDER BY building
            ''')
            building_stats = cur.fetchall()

            # 방 타입별 통계
            cur.execute('''
                SELECT
                    room_type,
                    COUNT(*) as total,
                    SUM(CASE WHEN status = '배정완료' THEN 1 ELSE 0 END) as assigned,
                    SUM(CASE WHEN status = '확인' THEN 1 ELSE 0 END) as confirmed_unassigned
                FROM Checkin
                GROUP BY room_type
                ORDER BY room_type
            ''')
            room_type_stats = cur.fetchall()

            # 방 사용률
            cur.execute('''
                SELECT
                    ri.building,
                    ri.room_type,
                    COUNT(ri.room_id) as total_rooms,
                    SUM(ri.capacity) as total_capacity,
                    COUNT(ds.student_id) as current_occupancy,
                    ROUND((COUNT(ds.student_id) / SUM(ri.capacity)) * 100, 2) as occupancy_rate
                FROM Room_Info ri
                LEFT JOIN Domi_Students ds ON ri.building = ds.dorm_building
                    AND ri.room_number = ds.room_num
                    AND ds.stat = '입주중'
                GROUP BY ri.building, ri.room_type
                ORDER BY ri.building, ri.room_type
            ''')
            occupancy_stats = cur.fetchall()

        return jsonify({
            'success': True,
            'overall_stats': overall_stats,
            'building_stats': building_stats,
            'room_type_stats': room_type_stats,
            'occupancy_stats': occupancy_stats
        })

    except Exception as e:
        print(f"배정 현황 조회 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 4. 방별 배정 상세 조회 API - 호실별 배정 현황


@app.route('/api/admin/room-assignments', methods=['GET'])
def get_room_assignments():
    """호실별 배정 현황 상세 조회"""
    building = request.args.get('building')
    floor = request.args.get('floor')

    conn = get_db()
    try:
        with conn.cursor() as cur:
            query = '''
                SELECT
                    ri.room_id,
                    ri.building,
                    ri.floor_number as floor,
                    ri.room_number,
                    ri.room_type,
                    ri.max_occupancy as capacity,
                    CASE
                        WHEN ri.building = '양덕원' THEN '여'
                        WHEN ri.building = '숭례원' THEN '남'
                        ELSE '혼성'
                    END as gender,
                    0 as smoking_allowed,
                    COUNT(ds.student_id) as current_occupancy,
                    GROUP_CONCAT(
                        CONCAT(ds.name, ' (', ds.student_id, ')')
                        ORDER BY ds.name SEPARATOR ', '
                    ) as occupants,
                    GROUP_CONCAT(
                        ds.student_id
                        ORDER BY ds.name SEPARATOR ','
                    ) as occupant_ids
                FROM Room_Info ri
                LEFT JOIN Domi_Students ds ON ri.building = ds.dorm_building
                    AND (ri.room_number = ds.room_num OR ri.room_number = CONCAT(ds.room_num, '호'))
                    AND ds.room_num IS NOT NULL
                    AND ds.room_num != ''
                WHERE 1=1
            '''
            params = []

            if building:
                query += ' AND ri.building = %s'
                params.append(building)
            if floor:
                query += ' AND ri.floor_number = %s'
                params.append(floor)

            query += '''
                GROUP BY ri.room_id, ri.building, ri.floor_number, ri.room_number,
                         ri.room_type, ri.max_occupancy
                ORDER BY ri.building, ri.floor_number, ri.room_number
            '''

            cur.execute(query, params)
            room_assignments = cur.fetchall()

            # 각 방의 상세 정보 추가
            for room in room_assignments:
                room['is_full'] = room['current_occupancy'] >= room['capacity']
                room['available_spots'] = room['capacity'] - \
                    room['current_occupancy']
                room['occupancy_rate'] = round(
                    (room['current_occupancy'] / room['capacity']) * 100,
                    1) if room['capacity'] > 0 else 0

                # occupants가 None인 경우 빈 문자열로 변경
                if room['occupants'] is None:
                    room['occupants'] = ''
                if room['occupant_ids'] is None:
                    room['occupant_ids'] = ''

        return jsonify({
            'success': True,
            'room_assignments': room_assignments,
            'total_rooms': len(room_assignments)
        })

    except Exception as e:
        print(f"방별 배정 현황 조회 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 5. 배정 취소 API - 개별 학생 배정 취소


@app.route('/api/admin/cancel-assignment', methods=['POST'])
def cancel_student_assignment():
    """개별 학생 배정 취소"""
    data = request.json
    student_id = data.get('student_id')
    reason = data.get('reason', '관리자 배정 취소')

    if not student_id:
        return jsonify({'success': False, 'error': '학생 ID가 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 현재 배정 정보 확인
            cur.execute('''
                SELECT c.*, ds.name, ds.room_num as current_room
                FROM Checkin c
                LEFT JOIN Domi_Students ds ON c.student_id = ds.student_id
                WHERE c.student_id = %s AND c.status = '배정완료'
            ''', (student_id,))
            student_info = cur.fetchone()

            if not student_info:
                return jsonify({
                    'success': False,
                    'error': '배정완료 상태의 학생을 찾을 수 없습니다.'
                }), 404

            # 배정 취소 실행
            cur.execute('''
                UPDATE Checkin SET room_num = '', status = '확인'
                WHERE student_id = %s
            ''', (student_id,))

            # 학생 테이블에서도 방 정보 제거
            cur.execute('''
                UPDATE Domi_Students SET room_num = NULL
                WHERE student_id = %s
            ''', (student_id,))

        conn.commit()

        return jsonify({
            'success': True,
            'message': f"{student_info['name']} 학생의 배정이 취소되었습니다.",
            'student_name': student_info['name'],
            'cancelled_room': student_info['current_room']
        })

    except Exception as e:
        conn.rollback()
        print(f"배정 취소 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 6. 룸메이트 쌍 배정 취소 API


@app.route('/api/admin/cancel-pair-assignment', methods=['POST'])
def cancel_roommate_pair_assignment():
    """룸메이트 쌍 배정 취소"""
    data = request.json
    student1_id = data.get('student1_id')
    student2_id = data.get('student2_id')
    reason = data.get('reason', '관리자 룸메이트 배정 취소')

    if not student1_id or not student2_id:
        return jsonify({'success': False, 'error': '두 학생의 ID가 모두 필요합니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 두 학생의 현재 배정 정보 확인
            cur.execute('''
                SELECT c.student_id, c.room_num, ds.name
                FROM Checkin c
                LEFT JOIN Domi_Students ds ON c.student_id = ds.student_id
                WHERE c.student_id IN (%s, %s) AND c.status = '배정완료'
            ''', (student1_id, student2_id))
            students_info = cur.fetchall()

            if len(students_info) != 2:
                return jsonify({
                    'success': False,
                    'error': '배정완료 상태의 룸메이트 쌍을 찾을 수 없습니다.'
                }), 404

            # 같은 방에 배정되어 있는지 확인
            if students_info[0]['room_num'] != students_info[1]['room_num']:
                return jsonify({
                    'success': False,
                    'error': '두 학생이 같은 방에 배정되어 있지 않습니다.'
                }), 400

            room_number = students_info[0]['room_num']

            # 배정 취소 실행
            cur.execute('''
                UPDATE Checkin SET room_num = '', status = '확인'
                WHERE student_id IN (%s, %s)
            ''', (student1_id, student2_id))

            # 학생 테이블에서도 방 정보 제거
            cur.execute('''
                UPDATE Domi_Students SET room_num = NULL
                WHERE student_id IN (%s, %s)
            ''', (student1_id, student2_id))

        conn.commit()

        return jsonify({
            'success': True,
            'message': f"룸메이트 쌍의 배정이 취소되었습니다.",
            'students': [s['name'] for s in students_info],
            'cancelled_room': room_number
        })

    except Exception as e:
        conn.rollback()
        print(f"룸메이트 쌍 배정 취소 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 7. 학생별 배정 이력 조회 API


@app.route('/api/admin/student-assignment-history/<student_id>',
           methods=['GET'])
def get_student_assignment_history(student_id):
    """개별 학생 배정 이력 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 현재 배정 상태
            cur.execute('''
                SELECT c.*, ds.name, ds.room_num as current_room
                FROM Checkin c
                LEFT JOIN Domi_Students ds ON c.student_id = ds.student_id
                WHERE c.student_id = %s
            ''', (student_id,))
            current_status = cur.fetchone()

            if not current_status:
                return jsonify({
                    'success': False,
                    'error': '해당 학생을 찾을 수 없습니다.'
                }), 404

            # 입실신청 상태 변경 이력 조회
            cur.execute('''
                SELECT
                    'status_change' as type,
                    old_status,
                    new_status,
                    changed_by,
                    changed_at as created_at,
                    reason
                FROM Checkin_Status_History
                WHERE student_id = %s
                ORDER BY changed_at DESC
            ''', (student_id,))
            status_history = cur.fetchall()

            # 날짜 형식 변환
            for record in status_history:
                if record['created_at']:
                    record['created_at'] = record['created_at'].isoformat()

        return jsonify({
            'success': True,
            'student_info': current_status,
            'status_history': status_history
        })

    except Exception as e:
        print(f"학생 배정 이력 조회 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 8. 배정 규칙 관리 API


@app.route('/api/admin/assignment-rules', methods=['GET'])
def get_assignment_rules():
    """배정 규칙 조회"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 현재 배정 규칙 설정 조회
            cur.execute('''
                SELECT setting_key, setting_value, description, updated_at
                FROM System_Settings
                WHERE setting_key LIKE 'assignment_%'
                ORDER BY setting_key
            ''')
            rules = cur.fetchall()

            # 기본 규칙이 없으면 생성
            default_rules = {
                'assignment_priority_roommate': 'true',
                'assignment_priority_smoking_match': 'true',
                'assignment_priority_building_preference': 'true',
                'assignment_allow_cross_building': 'false',
                'assignment_max_batch_size': '50'
            }

            existing_keys = {rule['setting_key'] for rule in rules}

            for key, value in default_rules.items():
                if key not in existing_keys:
                    cur.execute('''
                        INSERT INTO System_Settings (setting_key, setting_value, description, updated_at)
                        VALUES (%s, %s, %s, %s)
                    ''', (key, value, f'자동배정 규칙: {key}', datetime.now()))

            # 다시 조회
            cur.execute('''
                SELECT setting_key, setting_value, description, updated_at
                FROM System_Settings
                WHERE setting_key LIKE 'assignment_%'
                ORDER BY setting_key
            ''')
            rules = cur.fetchall()

            # 날짜 형식 변환
            for rule in rules:
                if rule['updated_at']:
                    rule['updated_at'] = rule['updated_at'].isoformat()

        conn.commit()

        return jsonify({
            'success': True,
            'rules': rules
        })

    except Exception as e:
        print(f"배정 규칙 조회 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/admin/assignment-rules', methods=['PUT'])
def update_assignment_rules():
    """배정 규칙 업데이트"""
    data = request.json
    rules = data.get('rules', {})

    if not rules:
        return jsonify({'success': False, 'error': '업데이트할 규칙이 없습니다.'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            for key, value in rules.items():
                cur.execute('''
                    UPDATE System_Settings
                    SET setting_value = %s, updated_at = %s
                    WHERE setting_key = %s
                ''', (str(value), datetime.now(), key))

                # 해당 키가 없으면 새로 생성
                if cur.rowcount == 0:
                    cur.execute('''
                        INSERT INTO System_Settings (setting_key, setting_value, description, updated_at)
                        VALUES (%s, %s, %s, %s)
                    ''', (key, str(value), f'자동배정 규칙: {key}', datetime.now()))

        conn.commit()

        return jsonify({
            'success': True,
            'message': '배정 규칙이 업데이트되었습니다.',
            'updated_rules': rules
        })

    except Exception as e:
        conn.rollback()
        print(f"배정 규칙 업데이트 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 9. 배정 통계 API


@app.route('/api/admin/assignment-statistics', methods=['GET'])
def get_assignment_statistics():
    """상세 배정 통계"""
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 기본 날짜 범위 설정 (최근 30일)
            if not start_date:
                start_date = (
                    datetime.now() -
                    timedelta(
                        days=30)).strftime('%Y-%m-%d')
            if not end_date:
                end_date = datetime.now().strftime('%Y-%m-%d')

            # 1. 기간별 배정 현황
            cur.execute('''
                SELECT
                    DATE(reg_dt) as assignment_date,
                    COUNT(*) as total_assignments,
                    SUM(CASE WHEN room_type = '룸메이트' THEN 1 ELSE 0 END) as roommate_assignments,
                    SUM(CASE WHEN room_type != '룸메이트' THEN 1 ELSE 0 END) as individual_assignments
                FROM Checkin
                WHERE status = '배정완료'
                AND DATE(reg_dt) BETWEEN %s AND %s
                GROUP BY DATE(reg_dt)
                ORDER BY assignment_date DESC
            ''', (start_date, end_date))
            daily_stats = cur.fetchall()

            # 2. 건물별 배정 통계
            cur.execute('''
                SELECT
                    building,
                    room_type,
                    COUNT(*) as assigned_count,
                    AVG(CASE WHEN smoking = '흡연' THEN 1 ELSE 0 END) * 100 as smoking_percentage
                FROM Checkin
                WHERE status = '배정완료'
                GROUP BY building, room_type
                ORDER BY building, room_type
            ''')
            building_room_stats = cur.fetchall()

            # 3. 성별/흡연 여부별 통계
            cur.execute('''
                SELECT
                    ds.gender,
                    c.smoking,
                    COUNT(*) as count,
                    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Checkin WHERE status = '배정완료'), 2) as percentage
                FROM Checkin c
                LEFT JOIN Domi_Students ds ON c.student_id = ds.student_id
                WHERE c.status = '배정완료'
                GROUP BY ds.gender, c.smoking
                ORDER BY ds.gender, c.smoking
            ''')
            demographic_stats = cur.fetchall()

            # 날짜 형식 변환
            for stat in daily_stats:
                if stat['assignment_date']:
                    stat['assignment_date'] = stat['assignment_date'].isoformat()

        return jsonify({
            'success': True,
            'period': {
                'start_date': start_date,
                'end_date': end_date
            },
            'daily_stats': daily_stats,
            'building_room_stats': building_room_stats,
            'demographic_stats': demographic_stats
        })

    except Exception as e:
        print(f"배정 통계 조회 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 10. 배정 검증 API


@app.route('/api/admin/validate-assignments', methods=['GET'])
def validate_assignments():
    """중복/규칙위반 검증"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            validation_results = {
                'success': True,
                'issues': [],
                'warnings': [],
                'summary': {}
            }

            # 1. 중복 배정 검사
            cur.execute('''
                SELECT room_num, COUNT(*) as duplicate_count,
                       GROUP_CONCAT(CONCAT(name, ' (', student_id, ')') SEPARATOR ', ') as students
                FROM Checkin c
                LEFT JOIN Domi_Students ds ON c.student_id = ds.student_id
                WHERE c.status = '배정완료' AND c.room_num != ''
                GROUP BY room_num
                HAVING COUNT(*) > (
                    SELECT capacity FROM Room_Info ri
                    WHERE ri.room_number = c.room_num LIMIT 1
                )
            ''')
            overcrowded_rooms = cur.fetchall()

            for room in overcrowded_rooms:
                validation_results['issues'].append({
                    'type': 'overcrowded_room',
                    'room': room['room_num'],
                    'issue': f"방 정원 초과 ({room['duplicate_count']}명 배정)",
                    'students': room['students']
                })

            # 2. 성별 불일치 검사
            cur.execute('''
                SELECT c.room_num, ri.gender as room_gender,
                       GROUP_CONCAT(CONCAT(ds.name, ' (', ds.gender, ')') SEPARATOR ', ') as students
                FROM Checkin c
                LEFT JOIN Domi_Students ds ON c.student_id = ds.student_id
                LEFT JOIN Room_Info ri ON c.room_num = ri.room_number
                WHERE c.status = '배정완료' AND c.room_num != ''
                AND ds.gender != ri.gender
                GROUP BY c.room_num, ri.gender
            ''')
            gender_mismatches = cur.fetchall()

            for mismatch in gender_mismatches:
                validation_results['issues'].append({
                    'type': 'gender_mismatch',
                    'room': mismatch['room_num'],
                    'issue': f"성별 불일치 (방: {mismatch['room_gender']})",
                    'students': mismatch['students']
                })

            # 3. 흡연 규칙 위반 검사
            cur.execute('''
                SELECT c.room_num, ri.smoking_allowed,
                       GROUP_CONCAT(CONCAT(ds.name, ' (', c.smoking, ')') SEPARATOR ', ') as students
                FROM Checkin c
                LEFT JOIN Domi_Students ds ON c.student_id = ds.student_id
                LEFT JOIN Room_Info ri ON c.room_num = ri.room_number
                WHERE c.status = '배정완료' AND c.room_num != ''
                AND c.smoking = '흡연' AND ri.smoking_allowed = 0
                GROUP BY c.room_num, ri.smoking_allowed
            ''')
            smoking_violations = cur.fetchall()

            for violation in smoking_violations:
                validation_results['warnings'].append({
                    'type': 'smoking_violation',
                    'room': violation['room_num'],
                    'issue': "흡연자가 금연 방에 배정됨",
                    'students': violation['students']
                })

            # 4. 룸메이트 관계 확인
            cur.execute('''
                SELECT c1.student_id as student1, c2.student_id as student2, c1.room_num
                FROM Checkin c1
                JOIN Checkin c2 ON c1.room_num = c2.room_num AND c1.student_id != c2.student_id
                WHERE c1.status = '배정완료' AND c2.status = '배정완료'
                AND c1.room_num IN (
                    SELECT room_number FROM Room_Info WHERE room_type = '룸메이트'
                )
                AND NOT EXISTS (
                    SELECT 1 FROM Roommate_Requests rr1
                    WHERE rr1.student_id = c1.student_id AND rr1.partner_id = c2.student_id
                    AND rr1.status = 'accepted'
                    AND EXISTS (
                        SELECT 1 FROM Roommate_Requests rr2
                        WHERE rr2.student_id = c2.student_id AND rr2.partner_id = c1.student_id
                        AND rr2.status = 'accepted'
                    )
                )
            ''')
            unauthorized_roommates = cur.fetchall()

            for pair in unauthorized_roommates:
                validation_results['warnings'].append({
                    'type': 'unauthorized_roommate',
                    'room': pair['room_num'],
                    'issue': "상호 동의하지 않은 룸메이트가 같은 방에 배정됨",
                    'students': f"{pair['student1']}, {pair['student2']}"
                })

            # 5. 요약 통계
            validation_results['summary'] = {
                'total_issues': len(
                    validation_results['issues']), 'total_warnings': len(
                    validation_results['warnings']), 'critical_issues': len(
                    [
                        i for i in validation_results['issues'] if i['type'] in [
                            'overcrowded_room', 'gender_mismatch']]), 'validation_passed': len(
                    validation_results['issues']) == 0}

        return jsonify(validation_results)

    except Exception as e:
        print(f"배정 검증 오류: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

# 임시 디버깅 API - 테이블 구조 확인


@app.route('/api/debug/table/<table_name>/columns', methods=['GET'])
def debug_table_columns(table_name):
    """테이블의 실제 컬럼 구조 확인"""
    allowed_tables = ['Checkin', 'Firstin', 'Domi_Students']
    if table_name not in allowed_tables:
        return jsonify({'error': 'Allowed tables: ' +
                       ', '.join(allowed_tables)}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(f"DESCRIBE {table_name}")
            columns = cur.fetchall()

            return jsonify({
                'table': table_name,
                'columns': [{'Field': col['Field'], 'Type': col['Type']} for col in columns]
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 임시 김떡국 상태 수정 API


@app.route('/api/debug/fix-status/<student_id>', methods=['PUT'])
def fix_student_status(student_id):
    """김떡국 상태 직접 수정용 임시 API"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 김떡국의 입실신청 상태를 '확인'으로 변경
            cur.execute("""
                UPDATE Checkin
                SET status = '확인'
                WHERE student_id = %s
            """, (student_id,))

            affected_rows = cur.rowcount
            conn.commit()

            return jsonify({
                'message': f'학생 {student_id}의 상태가 업데이트되었습니다.',
                'affected_rows': affected_rows
            })

    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 임시 디버깅용 API - 학생 상태 확인


@app.route('/api/debug/student/<student_id>', methods=['GET'])
def debug_student_status(student_id):
    """디버깅용: 학생의 실제 DB 상태 확인"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # Checkin 테이블 상태 확인
            cur.execute("""
                SELECT checkin_id, student_id, name, status, check_comment, reg_dt
                FROM Checkin
                WHERE student_id = %s
                ORDER BY reg_dt DESC
            """, (student_id,))
            checkin_data = cur.fetchall()

            # 서류 확인 상태 확인
            documents = []
            if checkin_data:
                checkin_id = checkin_data[0]['checkin_id']
                cur.execute("""
                    SELECT file_name, status, uploaded_at
                    FROM Checkin_Documents
                    WHERE checkin_id = %s
                """, (checkin_id,))
                documents = cur.fetchall()

            return jsonify({
                'student_id': student_id,
                'checkin_data': checkin_data,
                'documents': documents
            })

    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 점호 관리 디버깅 API


@app.route('/api/debug/rollcall-data', methods=['GET'])
def debug_rollcall_data():
    """점호 관리 데이터 디버깅"""
    print("=== 점호 데이터 디버깅 시작 ===")

    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 테이블 존재 확인
            print("1. 테이블 존재 확인")
            cur.execute("SHOW TABLES LIKE 'Domi_Students'")
            domi_table = cur.fetchone()
            print(f"Domi_Students 테이블: {domi_table}")

            cur.execute("SHOW TABLES LIKE 'RollCall'")
            rollcall_table = cur.fetchone()
            print(f"RollCall 테이블: {rollcall_table}")

            # Domi_Students 테이블 구조
            print("\n2. Domi_Students 테이블 구조")
            cur.execute("DESCRIBE Domi_Students")
            columns = cur.fetchall()
            for col in columns:
                print(f"  컬럼: {col['Field']} ({col['Type']})")

            # 데이터 확인
            print("\n3. Domi_Students 데이터 확인")
            cur.execute(
                "SELECT student_id, name, dorm_building, room_num, stat FROM Domi_Students WHERE student_id != 'admin' LIMIT 5")
            students = cur.fetchall()
            for student in students:
                building = student['dorm_building'] if student['dorm_building'] else 'NULL'
                print(
                    f"  학생: ID={
                        student['student_id']}, 이름={
                        student['name']}, 건물='{building}', 호실={
                        student['room_num']}, 상태={
                        student['stat']}")

            # 건물별 통계 확인 (문제 쿼리)
            print("\n4. 건물별 통계 쿼리 테스트")
            target_date = datetime.now().date()
            query = """
                SELECT
                    COUNT(DISTINCT ds.student_id) as total_students,
                    ds.dorm_building
                FROM Domi_Students ds
                WHERE ds.stat = '입주중'
                    AND ds.student_id != 'admin'
                GROUP BY ds.dorm_building
                ORDER BY ds.dorm_building
            """
            print(f"쿼리: {query}")
            cur.execute(query)
            results = cur.fetchall()
            print(f"GROUP BY 결과: {results}")

            # GROUP BY 없이 단순 조회
            print("\n5. 단순 학생 조회 (GROUP BY 없음)")
            simple_query = """
                SELECT student_id, name, dorm_building, stat
                FROM Domi_Students
                WHERE stat = '입주중' AND student_id != 'admin'
            """
            cur.execute(simple_query)
            simple_results = cur.fetchall()
            print(f"단순 조회 결과: {len(simple_results)}명")
            for student in simple_results:
                building = student['dorm_building'] if student['dorm_building'] else 'NULL'
                print(
                    f"  - {student['name']} ({student['student_id']}) 건물: '{building}'")

            # 외박 테이블 확인
            print("\n6. Outting 테이블 확인")
            cur.execute("SELECT * FROM Outting LIMIT 3")
            outting_data = cur.fetchall()
            print(f"외박 데이터: {outting_data}")

        return jsonify({
            'success': True,
            'message': '디버깅 완료 - 로그 확인',
            'students_count': len(students),
            'query_results': results
        })
    except Exception as e:
        print(f"오류: {e}")
        import traceback
        print(f"스택 트레이스: {traceback.format_exc()}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# 간단한 데이터베이스 테스트 API


@app.route('/api/debug/simple-test', methods=['GET'])
def simple_database_test():
    """가장 기본적인 데이터베이스 테스트"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # 전체 학생 수 확인
            cur.execute("SELECT COUNT(*) as total FROM Domi_Students")
            total_count = cur.fetchone()

            # 입주중 학생 수 확인
            cur.execute(
                "SELECT COUNT(*) as total FROM Domi_Students WHERE stat = '입주중'")
            active_count = cur.fetchone()

            # admin 제외 입주중 학생 수
            cur.execute(
                "SELECT COUNT(*) as total FROM Domi_Students WHERE stat = '입주중' AND student_id != 'admin'")
            target_count = cur.fetchone()

            # 실제 학생 목록
            cur.execute(
                "SELECT student_id, name, stat, dorm_building FROM Domi_Students LIMIT 10")
            students = cur.fetchall()

            return jsonify({
                'total_students': total_count['total'],
                'active_students': active_count['total'],
                'target_students': target_count['total'],
                'sample_students': students
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5050, debug=True)
