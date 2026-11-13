# Học thông minh với AI

App Android (Flutter) cho hackathon "Codex Community Hackathon – Hanoi" ngày 14/11/2026.

Biến tài liệu có sẵn (PDF, ảnh, văn bản) thành bài giảng, quiz và bài tập; chẩn đoán lỗ hổng kiến thức của học sinh; ôn tập đúng chỗ yếu.

## Tài liệu
- [CLAUDE.md](CLAUDE.md) — hướng dẫn làm việc cho dự án
- [docs/KE-HOACH.md](docs/KE-HOACH.md) — vấn đề, tính năng, kiến trúc, lịch trong ngày
- [docs/CHAM-DIEM-VA-DEMO.md](docs/CHAM-DIEM-VA-DEMO.md) — tiêu chí chấm, checklist, kịch bản trình bày

## Chạy trên điện thoại Android
1. Bật **Tùy chọn nhà phát triển → Gỡ lỗi USB** trên điện thoại, cắm cáp, chấp nhận hộp thoại tin cậy.
2. Kiểm tra môi trường và thiết bị:
   ```bash
   flutter doctor -v
   flutter devices
   ```
3. Chạy app:
   ```bash
   flutter run
   ```
4. Build APK cài thật để demo:
   ```bash
   flutter build apk --release
   ```
   File tạo ra ở `build/app/outputs/flutter-apk/app-release.apk`.

## Cấu hình khoá AI
API key chỉ để ở backend proxy (file `.env` không commit). App không chứa key.

## Ghi công
Ý tưởng sinh bài hai bước và giáo viên AI tham khảo từ [OpenMAIC](https://github.com/THU-MAIC/OpenMAIC) (MIT). Không sao chép mã nguồn.
