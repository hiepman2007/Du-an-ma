# Backend AI (Node.js 24 trở lên)

Giữ API key, ép đầu ra JSON theo schema, kiểm tra khối trước khi trả về app.

## Nhà cung cấp AI
Đặt `AI_PROVIDER=gemini` hoặc `AI_PROVIDER=openai` trong `.env`, app không phải sửa gì.

| | Gemini | OpenAI |
|---|---|---|
| API | Interactions API (`/v1beta/interactions`) | Responses API |
| Key | `GEMINI_API_KEY` (aistudio.google.com) | `OPENAI_API_KEY` |
| Model mặc định | `gemini-3.5-flash-lite` | `gpt-6-luna` |
| File tải lên | Gemini Files API, giữ 48 giờ. Tệp gốc của tài khoản được lưu ở kho riêng để gửi lại khi cần. | OpenAI Files |
| Tìm nguồn cho sổ | Tavily Search và Extract khi có `TAVILY_API_KEY`. Bộ nguồn công khai tích hợp cho DSA, Toán, Lý và Hóa. | Cùng luồng tìm nguồn |
| Lưu ý | Quota tính theo project. Dùng tài liệu công khai khi thử với Gemini API miễn phí. | Quota và tín dụng theo project |

Code: `lib/ai.js` (chọn nhà cung cấp, model, ghi chi phí), `lib/providers/gemini.js`, `lib/providers/openai.js`.

## Chạy cục bộ
```bash
npm install
npm run dev            # http://127.0.0.1:8787
npm test
```
Tạo `.env` với `AI_PROVIDER=gemini`, `GEMINI_API_KEY` và `APP_TOKEN` dành cho máy cục bộ. Có thể thêm `TAVILY_API_KEY` để thử tìm nguồn trực tiếp. Nếu dùng OpenAI, đặt `AI_PROVIDER=openai` và `OPENAI_API_KEY`.
Thử nhanh:
```bash
curl -H "X-App-Token: <APP_TOKEN>" http://localhost:8787/api/health
```

## Triển khai Vercel
1. Tạo tài khoản Vercel, cài CLI: `npm i -g vercel`.
2. Thiết lập Supabase và cấu hình biến môi trường theo [hướng dẫn tài khoản beta](../docs/BETA-TAI-KHOAN.md).
3. Đặt `AI_PROVIDER`, `GEMINI_API_KEY` hoặc `OPENAI_API_KEY`. Có thể thêm `MODEL_OUTLINE`, `MODEL_LESSON`, `MODEL_SMALL` và `TAVILY_API_KEY`.
4. Triển khai từ thư mục `server/`, rồi build app với `API_BASE_URL` của backend và cấu hình Supabase cho client.

Tệp tải lên cục bộ tối đa 3 MiB để vừa phần dữ liệu Base64. Bản tài khoản tải trực tiếp lên kho riêng với giới hạn 10 MiB. Mỗi request Vercel tối đa 60 giây theo cấu hình repo.

## Endpoint
| Endpoint | Việc |
|---|---|
| `POST /api/study/research` | Tìm theo chủ đề và phạm vi, trả nguồn phân loại và nhóm còn thiếu |
| `POST /api/study/source` | Nhập URL, cố gắng đọc nội dung và giữ liên kết khi chưa đọc được |
| `POST /api/study/outline` | Tạo sơ đồ theo chặng với mục tiêu, bài tiên quyết và nguồn |
| `POST /api/study/lesson` | Tạo bài giảng theo bước, mô phỏng và câu kiểm tra |
| `POST /api/study/ask` | Hỏi đáp theo nguồn đã chọn, có thể truyền bước học |
| `POST /api/study/artifact` | Tóm tắt, quiz nhanh, quiz tương tác và thẻ ghi nhớ |
| `POST /api/upload` | Demo cục bộ tải PDF/ảnh vào Files API, trả `fileId` và đoạn văn theo trang PDF nếu đọc được |
| `POST /api/course/outline` | Lên lộ trình khóa học |
| `POST /api/lesson` | Sinh bài học = chuỗi khối widget |
| `POST /api/exercises` | Bộ đề luyện: thêm N câu theo độ khó easy/medium/hard, không trùng câu đã có |
| `POST /api/ask` | Gia sư hỏi đáp: câu trả lời là 1–4 khối (chữ + LaTeX, ảnh, đồ thị/mô phỏng, giải từng bước, code demo). `webSearch: false` (mặc định) = chỉ dựa vào nguồn đã nạp (kiểu NotebookLM); `true` = được tra web, trả về `web[]` + `webMode` (`search` hoặc `wikipedia` dự phòng) |
| `POST /api/simulation` | Mô phỏng tùy biến: HTML tự chứa, đã chặn tài nguyên ngoài + CSP |
| `POST /api/interactive` | Thêm khối tương tác cho một khái niệm |
| `POST /api/explain` | Gia sư: gợi ý, giải thích, gốc lỗi |
| `POST /api/sources/search` | Tìm nguồn web (chỉ giữ URL từ công cụ tìm kiếm), gắn nhãn tin cậy |
| `GET /api/health`, `GET /api/usage` | Kiểm tra, chi phí token thực tế |
