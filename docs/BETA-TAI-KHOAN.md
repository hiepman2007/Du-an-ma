# Tài khoản và đồng bộ beta

## Supabase staging

1. Tạo project staging và chạy migration trong `supabase/migrations`. Bật đăng nhập email/mật khẩu, xác nhận email và SMTP. Trong cấu hình URL của Supabase, thêm URL web của bản staging và `hocthongminh://auth-callback` vào danh sách redirect.
2. Đặt `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, `STUDY_REQUIRE_AUTH=true`, `STUDY_WEB_ORIGINS` và cấu hình AI trong môi trường Node/Vercel. `STUDY_WEB_ORIGINS` nhận danh sách origin web phân tách bằng dấu phẩy. Publishable key có thể nằm trong client. Secret key và key Gemini/Tavily chỉ nằm ở backend.
3. Build Flutter với `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `API_BASE_URL` và `STUDY_AUTH_WEB_REDIRECT` trong `--dart-define-from-file`. Đặt `STUDY_AUTH_WEB_REDIRECT` thành URL tuyệt đối của app web, đúng giá trị đã cho phép trên Supabase. Android dùng deep link trên. Đường dẫn reset và xác nhận quay lại thiết bị đã yêu cầu email để phiên PKCE hoạt động.
4. Tệp PDF và ảnh được lưu trong bucket riêng `study-sources`. Chỉ bật `STUDY_PRIVATE_AI_ENABLED=true` sau khi cấu hình nhà cung cấp AI phù hợp với tài liệu riêng. Với Gemini miễn phí, giữ mặc định tắt và dùng tài liệu công khai cho demo. Tệp tải qua Supabase hỗ trợ tối đa 10 MB. [Chính sách dữ liệu của Gemini](https://ai.google.dev/gemini-api/terms)

## Hạn mức

Backend giới hạn lượt gọi model và tác vụ tìm nguồn riêng biệt. Các giá trị mặc định là `STUDY_MODEL_USER_DAILY=30`, `STUDY_MODEL_PROJECT_DAILY=200`, `STUDY_MODEL_PROJECT_PER_MINUTE=12`, `STUDY_SEARCH_USER_DAILY=10`, `STUDY_SEARCH_PROJECT_DAILY=100`, `STUDY_SEARCH_PROJECT_PER_MINUTE=8`. Bộ đếm ngày của app đổi ngày lúc 00:00 UTC. Kiểm tra quota thực của project Gemini và cấu hình các giới hạn tương ứng trước khi mở staging cho người dùng.

Chế độ thử cục bộ có thể chạy với `APP_TOKEN` trên loopback và không cấu hình Supabase. Bản hosted dùng JWT. Web local mở qua backend local hoặc proxy cùng máy để tránh nhúng token của backend hosted.

## Nghiệm thu

- Đăng ký hai tài khoản với email nhận được thư. Xác nhận email, đăng nhập, thử quên mật khẩu từ Chrome và Android rồi đăng xuất. Mở khóa mẫu khi chưa đăng nhập.
- Tạo sổ trên web, tải một PDF, đánh dấu bước và làm quiz. Đăng nhập Android với cùng tài khoản, mở lại đúng bước và lịch sử làm bài. Cập nhật cùng một phiên bản sổ trên hai thiết bị và kiểm tra thông báo xung đột.
- Tài khoản thứ hai chỉ xem được sổ của mình. Yêu cầu backend với mã sổ của tài khoản thứ nhất phải trả 404. Bucket riêng phải từ chối đường dẫn nguồn của tài khoản thứ nhất.
- Import một khóa cũ hai lần và kiểm tra chỉ có một bản. Đính kèm lại tệp cũ nếu dữ liệu chỉ còn mã tệp của nhà cung cấp AI.
