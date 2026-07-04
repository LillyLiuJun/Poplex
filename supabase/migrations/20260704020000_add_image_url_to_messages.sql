-- 优先级3 (图片落盘)：给 messages 表加 image_url 列，存上传到 Storage 后的公开 URL。
-- 对应 generate 函数新增的 uploadImage() 上传管线。
ALTER TABLE messages ADD COLUMN IF NOT EXISTS image_url text;
