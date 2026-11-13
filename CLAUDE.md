# CLAUDE.md — Hướng dẫn cho dự án

## Bối cảnh
Dự án hackathon "Codex Community Hackathon – Hanoi" (14/11/2026, 09:00–19:00).
Mục tiêu: app di động Android (Flutter) ứng dụng AI vào học tập.
Chi tiết kế hoạch: `docs/KE-HOACH.md`. Tiêu chí chấm và kịch bản demo: `docs/CHAM-DIEM-VA-DEMO.md`.

## Sản phẩm
"Học Thông Minh": biến **tài liệu có sẵn** (PDF, ảnh chụp, văn bản) thành khóa học tương tác. Nhiều vai trò (sinh viên, học sinh, người đi làm, giáo viên); nhóm đi đầu là **sinh viên ôn thi từ slide**.

Ba chức năng chính (tập trung, không mở rộng thêm trước khi 3 cái này chạy ổn trên máy thật):
1. **Tài liệu → bộ bài tập**: lộ trình, bài học có trích nguồn; "Bộ đề luyện" sinh thêm 5 câu theo độ khó Dễ/Vừa/Khó (`/api/exercises`).
2. **Deep interactive**: danh mục bộ máy mô phỏng 3 tầng (xem mục Cấu trúc).
3. **Gia sư hỏi đáp kiểu ChatGPT** (`lib/screens/tutor_chat_screen.dart`, `/api/ask`): câu trả lời là chuỗi khối do AI chọn (chữ + LaTeX, ảnh thật, đồ thị/mô phỏng, giải từng bước, code demo, câu kiểm tra), lưu theo bài (`Lesson.chat`).
Công thức hiển thị bằng **LaTeX** (`$...$`, `$$...$$`) qua `lib/widgets/rich_content.dart` (flutter_math_fork); server sửa lỗi escape LaTeX trong JSON (`repairLatex` ở `server/lib/ai.js`).
Phụ (giữ, không phát triển thêm): tìm nguồn web, tab Ôn tập, thống kê, khóa mẫu.

## Công nghệ
- Flutter + Dart, chỉ nhắm Android (thư mục `web/` chỉ dùng để xem giao diện nhanh trên trình duyệt, không dùng để demo).
- Import Material bằng `package:material_ui/material_ui.dart` (Flutter mới đã đánh dấu `package:flutter/material.dart` là lỗi thời). Tránh gói UI bên thứ ba truyền `ThemeData` của Material cũ (đã gặp lỗi với `flutter_markdown`, nên dùng `lib/widgets/rich_content.dart` tự viết: markdown đơn giản + LaTeX + khối code).
- Kiểm tra bố cục trên màn điện thoại bằng test giao diện (`test/lesson_screen_test.dart`, `test/chat_screen_test.dart`) — đã bắt được lỗi tràn hàng mà xem web không thấy.
- Lưu dữ liệu cục bộ: một file JSON (`lib/services/storage.dart`), đóng hẳn mở lại vẫn còn.
- Gọi AI qua backend `server/` (Node, Vercel). Chọn nhà cung cấp bằng `AI_PROVIDER=gemini|openai` (`server/lib/ai.js`): Gemini Interactions API hoặc OpenAI Responses API, cả hai ép JSON theo schema. Schema viết một lần trong `server/lib/schemas.js`; `adaptSchema` đổi `anyOf` cho Gemini. **Không bao giờ để API key trong app hoặc trong git.**
- Phong cách giao diện theo thinklogic.vn: `lib/theme.dart` (đỏ `#D01628`, nền `#F7F7F7`, thẻ trắng viền mảnh, `Eyebrow`, `SectionHeader`, `NumberTile`, `HeroCard`).
- Tham khảo ý tưởng từ OpenMAIC (MIT, https://github.com/THU-MAIC/OpenMAIC): sinh bài hai bước (lộ trình → bài học), chế độ tương tác. Không sao chép mã nguồn.

## Cấu trúc
- `lib/models/models.dart`: Course, Lesson, Block (JSON khớp `server/lib/schemas.js`), WebSource.
- `lib/widgets/blocks/`: danh mục widget AI được chọn, chia 3 tầng (AI chỉ chọn và điền tham số, không viết code):
  - Tầng 1, bộ máy chuyên biệt: `formula_lab`, `function_graph` (tiếp tuyến/diện tích/nghiệm/cực trị, hàm phụ), `reaction_lab` (phòng thí nghiệm hóa ảo, `chem_blocks.dart`), `chem_formula` (khối lượng mol, `lib/services/chem.dart`), `motion_sim` (ném xiên/rơi tự do/con lắc).
  - Tầng 2, dùng mọi môn: `text_section`, `mcq`, `true_false`, `fill_blank`, `matching`, `ordering`, `flashcards`, `step_solver`, `concept_map`, `image_card` (ảnh Wikimedia Commons có giấy phép, server tìm ở `server/lib/images.js`).
  - Tầng 3, dự phòng: `custom_sim` — AI viết HTML mô phỏng khi học sinh bấm (`/api/simulation`), server chặn tài nguyên ngoài + bọc CSP, app chạy trong WebView chặn điều hướng.
  - Thêm loại khối mới phải sửa: `server/lib/schemas.js` (BLOCK_TYPES + trường), `server/lib/validate.js`, prompt `CATALOG` trong `server/lib/prompts.js`, `BlockType` trong `models.dart` + `block_renderer.dart`. Dữ liệu riêng của bộ máy đọc qua `block.rawMap(...)`.
- `lib/screens/`: onboarding (vai trò), home_shell (4 tab), create_course (tài liệu | tìm trên mạng), roadmap, lesson, tutor_sheet, review, profile.
- `lib/data/sample_course.dart`: khóa mẫu soạn tay để xem giao diện / dự phòng.
- `server/api/*`: `upload`, `course/outline`, `lesson`, `exercises`, `ask`, `interactive`, `simulation`, `explain`, `sources/search`, `health`, `usage`.
- Khối `code_demo` (Tin học): `lib/widgets/blocks/code_block.dart`; AI ghi kết quả chạy, app không chạy code.

## Lệnh thường dùng
- App: `flutter analyze`, `flutter test`, `flutter run`.
- Server cục bộ: `cd server && cp .env.example .env` (người dùng tự điền key) rồi `npm run dev` (cổng 8787); test: `npm test`.
- Server production: https://hoc-thong-minh-api.vercel.app (Vercel project `hoc-thong-minh-api`, region Singapore/Hong Kong). Biến môi trường đặt trên Vercel (`AI_PROVIDER`, `GEMINI_API_KEY`, `APP_TOKEN`). Deploy lại: trong `server/` chạy `npx vercel deploy --prod --yes` (PowerShell: `npx.cmd`).
- Cấu hình app khi build: `app_config.json` (không commit, mẫu ở `app_config.example.json`, `APP_TOKEN` trùng với `server/.env` và Vercel).
- Chạy/build app: `flutter run --dart-define-from-file=app_config.json`, `flutter build apk --release --dart-define-from-file=app_config.json`.
- Gemini gói miễn phí: model có lúc báo 503 quá tải (server tự thử lại 2 lần); công cụ Google Search có thể bị 429 hết quota nếu key chưa bật thanh toán.

## Quy ước làm việc
- Trả lời và viết giao diện bằng **tiếng Việt**; tên biến/hàm bằng tiếng Anh.
- Ưu tiên thứ tự: (1) luồng AI chính chạy thật trên điện thoại thật, (2) vấn đề người dùng rõ ràng, (3) mở rộng. Đừng làm tính năng phụ trước khi 3 tính năng cốt lõi chạy ổn.
- Giao diện mobile: thanh tab dưới đáy, một câu hỏi mỗi màn hình, nút lớn dễ bấm bằng ngón cái, hiển thị từng phần khi AI đang sinh (skeleton), xử lý lỗi mạng rõ ràng.
- Mỗi tính năng phải có trạng thái đang tải, lỗi, và rỗng.
- Commit nhỏ, thường xuyên. Không commit file `.env`, key, hay `android/key.properties`.
- Cần ghi rõ phần nào làm **trước hackathon** và phần nào làm **trong ngày** (BTC yêu cầu nêu khi trình bày): ghi trong `docs/KE-HOACH.md`, mục "Nhật ký làm việc".

## Môi trường máy (đã cài)
- Flutter SDK: `D:\dev\flutter`
- Android SDK: `D:\dev\android-sdk` (`ANDROID_HOME` đã đặt)
- Bộ đệm Gradle: `D:\dev\gradle-home` (`GRADLE_USER_HOME`), bộ đệm npm: `D:\dev\npm-cache`. Ổ C gần đầy, không cài thêm công cụ lớn lên C.
- APK bản demo gần nhất được chép ra `D:\dev\apk\hoc-thong-minh.apk`.
- Kiểm tra: `flutter doctor -v`
- Chạy trên điện thoại: bật Tùy chọn nhà phát triển → Gỡ lỗi USB, cắm cáp, `flutter devices`, rồi `flutter run`.
- Build APK để cài thật: `flutter build apk --release` (file ở `build/app/outputs/flutter-apk/app-release.apk`).
