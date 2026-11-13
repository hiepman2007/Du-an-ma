# Học thông minh với AI

App Android (Flutter) cho hackathon "Codex Community Hackathon – Hanoi" ngày 14/11/2026.

Biến tài liệu có sẵn (PDF, ảnh, văn bản) thành bài giảng, quiz và bài tập; chẩn đoán lỗ hổng kiến thức của học sinh; ôn tập đúng chỗ yếu.

## Tài liệu
- [CLAUDE.md](CLAUDE.md) — hướng dẫn làm việc cho dự án
- [docs/KE-HOACH.md](docs/KE-HOACH.md) — vấn đề, tính năng, kiến trúc, lịch trong ngày
- [docs/CHAM-DIEM-VA-DEMO.md](docs/CHAM-DIEM-VA-DEMO.md) — tiêu chí chấm, checklist, kịch bản trình bày
- [docs/AI-SKILLS.md](docs/AI-SKILLS.md) — Ponytail, Flutter/Dart, Anthropic Skills và Rapid Prototyper đi kèm dự án

## Chuẩn bị trên máy khác

1. Cài Git, Flutter SDK tương thích Dart `^3.14.0`, Android SDK và Node.js 20 trở lên.
2. Clone kho mã nguồn và tải thư viện:
   ```bash
   git clone https://github.com/hiepman2007/Du-an-ma.git
   cd Du-an-ma
   flutter pub get
   ```
3. Sao chép `app_config.example.json` thành `app_config.json`, điền địa chỉ backend và `APP_TOKEN` của bạn. Nếu chạy backend riêng, sao chép `server/.env.example` thành `server/.env` rồi cấu hình nhà cung cấp AI.
4. Các thư mục `.claude/skills`, `.claude/agents` và `.agents/skills` đã nằm trong repo: mở Claude Code hoặc Codex tại thư mục dự án để nhận skill, không cần tải lại từng bộ.

`app_config.json`, `.env`, SDK, bộ đệm và file build được giữ ngoài Git. Giữ API key ở backend. Riêng bản web xem trước cần giữ token backend ở proxy cục bộ; không dùng cấu hình chứa token thật để biên dịch JavaScript.

## Chạy trên điện thoại Android
1. Bật **Tùy chọn nhà phát triển → Gỡ lỗi USB** trên điện thoại, cắm cáp, chấp nhận hộp thoại tin cậy.
2. Kiểm tra môi trường và thiết bị:
   ```bash
   flutter doctor -v
   flutter devices
   ```
3. Chạy app:
   ```bash
   flutter run --dart-define-from-file=app_config.json
   ```
4. Build APK cài thật để demo:
   ```bash
   flutter build apk --release --dart-define-from-file=app_config.json
   ```
   File tạo ra ở `build/app/outputs/flutter-apk/app-release.apk`.

## Cấu hình khoá AI
API key chỉ để ở backend proxy (file `.env` không commit). App không chứa key.

## Ghi công
Ý tưởng sinh bài hai bước và giáo viên AI tham khảo từ [OpenMAIC](https://github.com/THU-MAIC/OpenMAIC) (MIT). Không sao chép mã nguồn.
