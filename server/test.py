import MySQLdb

# DB 접속 정보 입력!
db = MySQLdb.connect(
    host="175.106.96.149",         # 예: "175.106.96.149"
    user="admin",               # 또는 팀원이 만든 계정
    passwd="tkfkdgo1!",          # MySQL 비번
    db="KBU_DOMI",              # DB 이름 (기존에 만든 거)
    charset="utf8"
)

print("✅ MySQL 연결 성공!")

db.close()