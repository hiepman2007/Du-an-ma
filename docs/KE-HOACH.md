# Kế hoạch dự án

## 1. Vấn đề (điền số thật sau khảo sát)
- **Người dùng chính:** giáo viên/gia sư dạy kèm; **người dùng cuối:** học sinh lớp 9–12.
- **Nỗi đau:**
  - Giáo viên mất [X] giờ mỗi tuần soạn bài tập từ tài liệu.
  - Học sinh làm sai nhưng không biết hổng kiến thức nào nên ôn không đúng chỗ.
- **AI giúp trực tiếp:** biến tài liệu thành bài giảng/bài tập trong vài phút; chẩn đoán lỗ hổng từng học sinh.
- **Bằng chứng cần có:** kết quả khảo sát (số phản hồi, số liệu chính), 3–5 trích dẫn phỏng vấn nguyên văn, số đo trước/sau (soạn tay vs dùng app), phản hồi từ người dùng thật tại sự kiện.

## 2. Tính năng

### Cốt lõi
1. **Tài liệu → bài giảng + quiz + bài tập**
   - Nhập: PDF, ảnh chụp (camera/thư viện), văn bản dán vào.
   - Pipeline hai bước: (a) AI tạo dàn ý các phần; (b) với mỗi phần sinh bài giảng tóm tắt, câu hỏi (trắc nghiệm, điền khuyết, tự luận ngắn) và đáp án kèm giải thích.
   - Mỗi câu có **trích dẫn** đoạn nguồn trong tài liệu (chống bịa, tạo niềm tin).
   - Tùy chọn: số câu, độ khó, mức độ (ôn tập/kiểm tra).
   - Hiển thị từng phần ngay khi sinh xong, không chờ cả khối.
2. **Chẩn đoán lỗ hổng + gia sư gợi mở**
   - Làm sai → AI hỏi gợi ý từng bước (không đưa đáp án ngay), xác định gốc lỗi (khái niệm thiếu), sinh 2–3 câu luyện đúng điểm yếu.
   - Tuỳ chọn "bạn học AI" đặt câu hỏi ngược để học sinh giải thích lại.
3. **Ôn tập thông minh**
   - Mỗi lỗi sai thành thẻ ôn; lặp lại ngắt quãng (ví dụ 1 → 3 → 7 → 14 ngày).
   - Lịch ôn theo ngày thi người dùng nhập.
   - Màn hình "Điểm yếu của tôi" gom theo chủ đề.

### Làm thêm nếu còn thời gian (theo thứ tự ưu tiên)
1. Chia sẻ bộ đề qua mã/QR cho cả lớp (vòng lặp lan truyền, hỗ trợ điểm mở rộng).
2. TTS đọc bài giảng.
3. Flashcard từ bài giảng.
4. Bảng thống kê cho giáo viên (ai sai nhiều câu nào).
5. Lưu offline toàn bộ bài đã tạo.

## 3. Màn hình (bố cục mobile)
Thanh tab dưới đáy: **Tạo** | **Học** | **Ôn** | **Hồ sơ**.
- **Tạo:** chọn nguồn (chụp ảnh / PDF / dán văn bản) → tuỳ chọn → màn hình sinh bài (hiển thị từng phần).
- **Học:** danh sách bộ bài → bài giảng → làm quiz (một câu mỗi màn hình, vuốt để qua câu) → kết quả + chẩn đoán.
- **Ôn:** thẻ đến hạn hôm nay → "Điểm yếu của tôi" → lịch ôn.
- **Hồ sơ:** ngày thi, cài đặt, mã chia sẻ.

## 4. Kiến trúc
```
Flutter app (Android)
  ├─ UI (màn hình, tab)
  ├─ Trạng thái (Riverpod hoặc Provider)
  ├─ Lưu cục bộ (bộ đề, lịch sử, thẻ ôn)
  └─ Client gọi API ──► Backend proxy nhỏ ──► API mô hình AI (hỗ trợ ảnh/PDF)
                         (giữ API key, giới hạn tần suất, trả JSON đã kiểm tra)
```
- Backend proxy: một dịch vụ nhỏ (Node/Express hoặc Cloudflare Worker). Nhận tài liệu hoặc văn bản, gọi mô hình, ép đầu ra theo **JSON schema**, trả về app.
- Prompt đặt ở backend để chỉnh nhanh mà không phải build lại app.
- Dữ liệu quiz dùng cấu trúc cố định: `{ question, type, options, answer, explanation, sourceQuote, topic }`.

## 5. Thứ tự làm trong ngày (14/11)
| Giờ | Việc |
|---|---|
| 09:00–11:00 | Sự kiện: chốt đội 3–4 người, phân vai. Nếu đã có nền thì kiểm tra lại build chạy trên điện thoại |
| 11:00–12:30 | Luồng 1: nhập tài liệu → sinh quiz, hiển thị trên điện thoại |
| 12:30–14:00 | Luồng 2: làm quiz, chẩn đoán, gia sư gợi mở |
| 14:00–15:30 | Luồng 3: thẻ ôn và lịch ôn, lưu cục bộ |
| 15:30–16:00 | **Build APK release, cài thật, đóng hẳn rồi mở lại để kiểm tra.** Chuẩn bị slide/bằng chứng |
| 16:00 | Dừng build, nộp bài |
| 16:15 | Trình bày 5 phút |

## 6. Rủi ro và cách xử lý
- **Mạng hội trường yếu:** có dữ liệu mẫu đã sinh sẵn, lưu cục bộ, để demo vẫn chạy nếu AI chậm.
- **AI sinh sai định dạng:** ép JSON schema, kiểm tra và thử lại 1 lần.
- **API key lộ:** chỉ để ở backend, file `.env` không commit.
- **Build Android lỗi sát giờ:** build APK thử sớm (tối nay), không để cuối ngày mới thử.

## 7. Nhật ký làm việc (cần cho phần "nêu rõ phần có trước")
| Ngày | Việc đã làm | Trước hay trong hackathon |
|---|---|---|
| 13/11 | Cài Flutter và Android SDK, lên kế hoạch, khảo sát | Trước |
| 13/11 | Backend `server/` (upload, lộ trình, bài học, tương tác, gia sư, tìm nguồn web có xác thực); app Flutter: 4 tab, tạo khóa học từ tài liệu/web, lộ trình sửa được, bài học gồm 9 loại widget do AI chọn, gia sư AI, ôn chủ đề yếu, thống kê; giao diện theo phong cách thinklogic.vn; khóa mẫu dự phòng. Chưa chạy thử với API key thật | Trước |
| 13/11 | V2 (`docs/KE-HOACH-V2.md`): sổ học tập Nguồn · Hỏi đáp · Studio, sơ đồ lộ trình có trạng thái, quiz tương tác 3 bước, Canvas | Trước |
| 13/11 | Chat gia sư kiểu ChatGPT: gộp chat của sổ và chat từng bài thành một màn (`TutorChat`), nhiều cuộc trò chuyện ở ngăn kéo có tìm kiếm, đổi ngữ cảnh cả khóa / một bài, nút "+" (đính PDF/ảnh, chọn nguồn, tra cứu web), chế độ Gợi mở, sao chép / tạo lại / sửa câu hỏi / dừng, chữ hiện dần | Trước |

> Ghi chú: kế hoạch chi tiết mới nhất (luồng chính kiểu OpenMAIC, danh mục widget, chi phí API) đã thay cho mục 2–5 phía trên; xem `CLAUDE.md` mục Cấu trúc.
