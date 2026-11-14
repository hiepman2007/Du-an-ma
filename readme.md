# Học Thông Minh

App Android (Flutter) cho hackathon "Codex Community Hackathon – Hanoi" ngày 14/11/2026.

Biến tài liệu có sẵn (PDF, ảnh, văn bản) thành bài giảng, quiz và bài tập; chẩn đoán lỗ hổng kiến thức của học sinh; ôn tập đúng chỗ yếu.

## Chức năng chính

- **Lên plan học**: chia môn thành từng chặng theo ngày thi và thời gian rảnh mỗi ngày.
- **Cá nhân hóa**: ghi nhớ bạn sai ở đâu, nhắc ôn đúng phần đó.
- **Trợ lý AI kiểu ChatGPT**: trả lời từ tài liệu bạn nạp; thiếu tài liệu thì dùng kiến thức chung hoặc tự tra web và ghi nguồn.
- **Mô phỏng bằng AI**: với câu hỏi về một quá trình (quang hợp, mạch điện, cung cầu…), AI dựng riêng một ứng dụng mô phỏng ngay trong câu trả lời. Phòng thí nghiệm ảo có sẵn 10 thí nghiệm vật lý, hóa học chạy không cần mạng.
- **Hoạt động học**: quiz, thẻ ghi nhớ, trò ghép nhanh, thi thử bấm giờ.

Bố cục: trang chủ có thống kê và ô hỏi AI. Mỗi sổ học có ba phần Chat · Nguồn · Studio (theo kiểu NotebookLM), kèm hàng công cụ ngay trên ô chat.

## Thuyết trình

Bộ slide 6 trang: [Học Thông Minh, thuyết trình](https://drive.google.com/file/d/1kC5WeBbm8-BcEnzWRLuoeO_QCCxmaVCH/view?usp=sharing) (cần chủ sở hữu chia sẻ link thì người khác mới mở được). Nội dung từng trang:

### 1. Vấn đề hiện tại
**Mở tập slide cả trăm trang, bạn bắt đầu ôn từ đâu?**
- Khó hiểu: khái niệm trừu tượng, chỉ có chữ và công thức, chưa từng thấy hiện tượng diễn ra.
- Thiếu thu hút: ngồi nghe một chiều, ít khi được tự tay thử hay hỏi lại ngay.
- Slide quá dài: chữ dày đặc, ít hình, ôn lại chỉ biết đọc từ đầu.

### 2. Bằng chứng
**Chán học và mất tập trung phổ biến hơn ta nghĩ**
- ~60% sinh viên thấy ít nhất một nửa số buổi giảng là nhàm chán (Mann & Robinson, 2009).
- 44% học sinh lớp 12 còn hứng thú với việc học, so với 76% ở lớp 5 (Gallup Student Poll, 2013).
- Sinh viên không giữ được tập trung liền mạch 10-20 phút như vẫn tưởng (Bunce, Flens & Neiles, 2010).

### 3. Hậu quả
**Học thụ động, nhớ không lâu, ôn không có hướng**
- Một tuần sau: chỉ đọc lại nhớ 40%, tự kiểm tra nhớ 61% (Roediger & Karpicke, 2006).
- Tỉ lệ rớt môn: chỉ nghe giảng 33,8%, học chủ động 21,8% (Freeman và cộng sự, 2014).
- Không có lộ trình thì ôn lan man: sinh viên được hướng dẫn đặt mục tiêu và kế hoạch học đạt điểm trung bình 2,91, nhóm còn lại 2,46, thang 4 (Morisano và cộng sự, 2010).

### 4. Giải pháp: Học Thông Minh, học có AI đi cùng
| Chức năng | Mô tả |
|---|---|
| Lên plan học | Chia môn thành từng chặng theo ngày thi, tổng hợp kiến thức cần học |
| Cá nhân hóa | Nhớ bạn sai ở đâu, nhắc ôn đúng phần đó |
| Trợ lý AI | Hỏi gì cũng được, trả lời chi tiết |
| Mô phỏng bằng AI | Thí nghiệm, hiện tượng dựng riêng cho câu hỏi |
| Hoạt động học | Quiz, thẻ ghi nhớ, ghép nhanh, thi thử, game |
| Bắt đầu dễ dàng | Thêm slide hoặc gõ tên môn để AI phân tích |

### 5. Demo: trước và sau khi có AI
| Việc | Trước khi có AI | Với Học Thông Minh |
|---|---|---|
| Hiểu khái niệm | Đọc chữ, tự hình dung | Ảnh thật, kéo thử mô phỏng |
| Giữ hứng thú | Ngồi nghe một chiều | Quiz, ghép nhanh, thí nghiệm ảo |
| Biết học gì trước | Tự mò, đọc từ đầu | Lộ trình theo ngày thi |
| Hỏi khi không hiểu | Chờ buổi học thêm | Trợ lý AI, khoảng 13 giây |
| Xem một thí nghiệm | Cần phòng lab, video | AI dựng trong khoảng 1 phút |

Học qua mô phỏng có hiệu quả lớn (g = 0,85, tổng hợp 145 nghiên cứu; Chernikova và cộng sự, 2020). Học kèm một thầy một trò giúp học sinh trung bình vượt 98% bạn học trên lớp (Bloom, 1984). Thời gian của app đo trên máy chủ thật ngày 14/11/2026.

Kịch bản demo: hỏi "Quang hợp diễn ra thế nào?" → câu trả lời kèm mô phỏng chiếc lá → gõ "lập lộ trình ôn Sinh 2 tuần" → làm quiz → tắt hẳn app, mở lại, dữ liệu vẫn còn.

### 6. Đội ngũ
Nhóm DUANMA gồm ba thành viên: Nguyễn Văn Khánh Duy, Mẫn Đức Hiệp và Ngô Tiến Thành.

### Nguồn số liệu
- Mann, S. & Robinson, A. (2009). Boredom in the lecture theatre. *British Educational Research Journal*, 35(2), 243-258.
- Gallup Student Poll (2013). Student engagement by grade.
- Bunce, D. M., Flens, E. A. & Neiles, K. Y. (2010). How long can students pay attention in class? *Journal of Chemical Education*, 87(12), 1438-1443.
- Roediger, H. L. & Karpicke, J. D. (2006). Test-enhanced learning. *Psychological Science*, 17(3), 249-255.
- Freeman, S. và cộng sự (2014). Active learning increases student performance in science, engineering, and mathematics. *PNAS*, 111(23).
- Morisano, D. và cộng sự (2010). Setting, elaborating, and reflecting on personal goals improves academic performance. *Journal of Applied Psychology*, 95(2), 255-264.
- Chernikova, O. và cộng sự (2020). Simulation-based learning in higher education: a meta-analysis. *Review of Educational Research*, 90(4), 499-541.
- Bloom, B. S. (1984). The 2 sigma problem. *Educational Researcher*, 13(6), 4-16.

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
