# Forest Camp v2

ฉากค่ายพักแรมกลางป่ายามเย็น พร้อมตัวละคร 3 ตัวที่ท่าทางต่างกัน สร้างด้วย Godot 4.7

▶️ **เล่นได้ที่:** https://nattapongsric-collab.github.io/forest-camp-game/

## โครงสร้าง repo

- **ไฟล์ `index.*` ที่ root:** เกมที่ export เป็นเว็บ (GitHub Pages ใช้ไฟล์ชุดนี้)
- **โฟลเดอร์ `source/`:** โปรเจกต์ Godot ต้นฉบับ (`project.godot`, `main.tscn`, `forest_camp.gd`, `icon.svg`) วิธีเปิดดูใน `source/README.txt`

## ไฟล์เกมเวอร์ชันเว็บ

| ไฟล์ | หน้าที่ |
|---|---|
| `index.html` | หน้าเว็บที่โหลดเกม |
| `index.js` | ตัวโหลด Godot engine |
| `index.wasm.gz` | Godot engine (WebAssembly) แบบบีบอัด ให้อัปผ่านหน้าเว็บ GitHub ได้ (`index.html` แตกไฟล์ให้ตอนโหลด) |
| `index.pck` | ข้อมูลเกม (ซีน สคริปต์ `forest_camp.gd` ไอคอน) |
| `index.audio.worklet.js`, `index.audio.position.worklet.js` | ระบบเสียง |
| `index.png`, `index.icon.png`, `index.apple-touch-icon.png` | ภาพ splash และไอคอน |

## รันในเครื่อง

เปิด `index.html` ตรงๆ ไม่ได้ ต้องรันผ่าน web server:

```bash
python -m http.server 8000
```

แล้วเปิด http://localhost:8000
