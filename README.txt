วิธีเปิด
1. แตกไฟล์ zip
2. เปิด Godot 4.7 -> Project Manager -> Import -> เลือกไฟล์ project.godot ในโฟลเดอร์นี้
3. กด F5 เพื่อเล่น

ใส่ตัวละครของตัวเอง (Blender + Mixamo)
1. ลากไฟล์ .glb/.fbx ของตัวละครและไฟล์ MeleeLib.res / ShooterLib.res ไว้ในโปรเจกต์
2. เปิด main.tscn -> คลิก node ForestCamp -> ใน Inspector
   - Character Scene: ลากไฟล์ตัวละครมาใส่
   - Animation Library Path: เลือก MeleeLib.res หรือ ShooterLib.res
3. กด F5 อีกครั้ง (ถ้า Character Scene ว่าง จะใช้ตัวชิบิในตัวสคริปต์)
