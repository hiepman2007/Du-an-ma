# Kế hoạch V2: 3 chức năng chính + chức năng cơ bản kiểu StudyFetch

Viết ngày 13/11/2026, trước hackathon 14/11. Kế hoạch này thay plan "sổ học tập" của Codex: giữ phần Codex đã làm, cắt phần chưa cần. Mục 2 và 3 đã bổ sung sau khi xem trực tiếp StudyFetch (studyfetch.com) bằng tài khoản thật.

## 0. Hiện trạng (Codex đã làm, commit `468208b`)

`flutter analyze` không có lỗi; `flutter test` 23/24 qua (1 test chờ chữ "Tiếp tục học" trên khóa mới, sửa cùng màn lộ trình). Máy này chưa cài Node nên chưa chạy test server.

| Phần | Đã có | Ghi chú |
|---|---|---|
| Sổ học (`notebook_screen.dart`) | 3 khu vực Nguồn · Hỏi đáp · Studio | Chat của sổ là một màn chat thứ hai, tách khỏi `tutor_chat_screen.dart` |
| Lộ trình (`roadmap_screen.dart`) | Chia theo chặng (`Lesson.phase`), bài cần học trước, nút "Tiếp tục học" | Các chặng xếp thành cột, chưa phải sơ đồ có mũi tên |
| Mục tiêu (`study_goal_sheet.dart`, `StudyBrief`) | Mục tiêu, ngày thi, số phút mỗi ngày | Đã tính `scheduledAt` cho từng bài |
| Studio (`StudyArtifact`) | Tóm tắt, quiz nhanh, quiz tương tác, flashcards; lưu lịch sử làm bài (`QuizAttempt`) | |
| Mô phỏng DSA | Tìm kiếm nhị phân, BFS/DFS (`lib/widgets/study/`) | |
| Tìm nguồn (`server/lib/research.js`) | Tavily, dự phòng bằng danh sách nguồn MIT OCW/OpenStax/PhET | Cần `TAVILY_API_KEY` |
| Tài khoản (`account.js`, `supabase/`) | Supabase Auth + bảng dữ liệu | **Tắt**: giữ code, không cấu hình `SUPABASE_URL` |

## 1. Phạm vi

**Làm kỹ, có AI (3 chức năng chính):**
1. Sắp xếp lộ trình
2. Quiz tương tác
3. Chat gia sư giao diện kiểu ChatGPT

**Làm cơ bản, không gọi thêm AI:** lịch học, trò chơi Ghép nhanh, thi thử, flashcards và tóm tắt (đã có).

**Phần Codex đã làm:** giữ sổ Nguồn · Hỏi đáp · Studio. Tài khoản Supabase giữ code nhưng tắt bằng biến môi trường.

**Không làm:** ghi âm bài giảng, video giải thích, tóm tắt bằng âm thanh, nhắn tin qua iMessage, plugin, mini app, chấm bài luận, tài khoản/đồng bộ (để sau hackathon).

## 2. Ba chức năng chính

### 2.1. Sắp xếp lộ trình
- **Sơ đồ thật**: mỗi bài là một ô, mũi tên nối theo `prerequisites`, nhóm theo chặng. Bài không phụ thuộc nhau đứng cùng hàng. Nếu AI không ghi quan hệ học trước thì sơ đồ là một đường thẳng.
- **Trạng thái rõ**: Chưa mở khóa (thiếu bài trước) · Có thể học · Đang học · Đã xong. Đánh dấu xong do người học bấm, không bị quiz làm mất.
- **Hai chỉ số tách riêng** (như StudyFetch): *đã học* (số bài đã xong) và *nắm vững* (số bài có tỉ lệ đúng ≥ 80%). Bài dưới 60% hiện nhãn "Nên ôn lại".
- **Bấm vào một bài** mở bảng chi tiết: mục tiêu, bài cần học trước, mức nắm vững, và các cách học bài đó (Học bài giảng · Hỏi gia sư về bài này · Làm quiz bài này · Flashcards), cùng nút đánh dấu đã xong.
- **Chế độ học** (quy tắc trong app, không gọi AI): *Cấp tốc* chỉ giữ bài quan trọng nhất (khoảng 40%, ưu tiên bài là gốc của nhiều bài khác), *Chuẩn*, *Đầy đủ*. Đổi chế độ không xóa tiến độ.
- **Kiểm tra đầu chặng** (đợt sau nếu kịp): 3 câu nhanh, đúng hết thì cho đánh dấu cả chặng đã biết.
- **Xếp lại khi đổi mục tiêu hoặc ngày thi**: chỉ xếp lại phần chưa học, giữ kết quả đã có.
- Giữ cách sinh 2 bước: lượt 1 tạo sơ đồ, lượt 2 tạo bài đầu tiên. Bài sau chỉ sinh khi mở.

### 2.2. Quiz tương tác (giống QuizFetch)
- **Tạo quiz 3 bước** (StudyFetch dùng 4 bước, gộp bước đặt tên):
  1. Chọn nguồn: tài liệu đang bật, một bài trong lộ trình, hoặc bộ flashcards.
  2. Chọn số câu cho từng loại: trắc nghiệm, đúng/sai, điền khuyết, ghép cặp, sắp xếp, và **đoạn văn 3 tầng** (một đoạn tình huống + 3 câu: nhận biết → giải thích cơ chế → vận dụng).
  3. Độ khó Dễ/Vừa/Khó, kiểu giải thích (ngắn gọn / chi tiết nhiều ví dụ), chủ đề trọng tâm (tùy chọn), rồi Tạo.
- **Làm bài**: một câu mỗi màn, thanh tiến độ, nút lớn. Trả lời xong hiện ngay đúng/sai và **giải thích vì sao sai**, kèm trích nguồn bấm được.
- **Sau khi làm**: điểm theo chủ đề (đưa về mức nắm vững của lộ trình), "Làm lại câu sai", "Hỏi gia sư về câu này" (mở chat với câu hỏi đã điền sẵn).
- Lưu mọi lượt làm (`QuizAttempt`). Tạo lại quiz thì ra phiên bản mới, giữ điểm cũ.

### 2.3. Chat gia sư kiểu ChatGPT
- **Một màn chat duy nhất**: gộp chat của sổ và `tutor_chat_screen.dart`. Ngữ cảnh là cả khóa hoặc một bài, đổi bằng một nút ở đầu màn.
- **Giao diện**:
  - tin nhắn người dùng là bong bóng bên phải, câu trả lời AI chiếm hết chiều ngang;
  - ô nhập dính đáy; nút **"+"** mở: đính kèm ảnh/PDF, chọn nguồn dùng cho câu hỏi, bật tra cứu web;
  - công tắc **Gợi mở** ngay cạnh ô nhập (gia sư hỏi gợi ý để người học tự tìm đáp án);
  - câu gợi ý khi chat trống, **đổi theo ngữ cảnh** (đang ở bài nào, vừa sai câu nào);
  - danh sách hội thoại ở ngăn kéo bên trái, có ô tìm kiếm;
  - trên màn rộng (web/máy tính bảng), khung chat luôn mở ở cột phải như StudyFetch.
- **Thao tác trên câu trả lời**: sao chép, tạo lại, sửa câu hỏi rồi gửi lại, nút dừng khi đang sinh.
- **Hiển thị dần**: thử truyền dữ liệu (stream) phần chữ từ server. Nếu không kịp thì hiện chữ chạy và skeleton cho từng khối. Vẫn giữ các khối đặc biệt (LaTeX, đồ thị, giải từng bước, câu kiểm tra).
- Giữ công tắc `allowWeb` hiện có.

## 3. Chức năng cơ bản (không AI)
- **Lịch học**: xem theo tuần, tính từ lộ trình, số phút mỗi ngày và ngày thi; mỗi ngày có các bài cần học, tích xong. Nếu trễ thì dồn bài sang ngày sau. Có nút "Thêm ngày thi". Không gửi thông báo, không nối Google Calendar.
- **Trò chơi "Ghép nhanh"**: lấy cặp từ flashcards hoặc câu ghép cặp đã có, đếm giờ, lưu điểm cao nhất. Không sinh nội dung mới.
- **Thi thử**: dùng lại màn tạo quiz, thêm đồng hồ đếm ngược; không hiện đáp án giữa chừng, chấm điểm ở cuối.
- **Flashcards**: giữ như Codex đã làm; thêm mục "Thẻ đến hạn hôm nay" (ôn ngắt quãng đơn giản: đúng thì giãn 1 → 3 → 7 ngày, sai thì về 1 ngày).
- **Tóm tắt**: giữ như Codex đã làm.

## 4. Thứ tự làm
1. ~~Commit phần Codex đã làm làm mốc~~ (xong, nhánh `v2-lo-trinh-quiz-chat`).
2. Sơ đồ lộ trình với trạng thái, hai chỉ số, bảng chi tiết bài (2.1). Chế độ học làm sau cùng của bước này.
3. Màn tạo quiz và màn làm quiz (2.2), lưu điểm theo chủ đề để lộ trình hiện mức nắm vững.
4. Gộp hai màn chat và làm giao diện kiểu ChatGPT đầy đủ (2.3).
5. Lịch học, trò chơi Ghép nhanh, thi thử, thẻ đến hạn (mục 3).
6. Build APK, chạy thử trên điện thoại thật: tạo khóa từ một dòng, xem sơ đồ, học bài 1, làm quiz, hỏi gia sư, đóng rồi mở lại app vẫn còn tiến độ.

Mỗi màn mới phải có trạng thái đang tải, lỗi và rỗng, và có test giao diện trên kích thước điện thoại.

## 5. Rủi ro
- **Hết quota Gemini**: dùng khóa mẫu có nhãn rõ. Lịch học và trò chơi chạy không cần AI.
- **Stream trên Vercel không ổn định**: dùng hiệu ứng chữ chạy ở phía app.
- **Không có `TAVILY_API_KEY`**: dùng danh sách nguồn dự phòng có sẵn.
- **Phần tài khoản Supabase đã nằm trong code**: để trống `SUPABASE_URL` và kiểm tra app chạy bình thường khi không đăng nhập.
