SET search_path TO nsq, public;

-- 카테고리
CREATE TABLE IF NOT EXISTS board_category (
  id BIGSERIAL PRIMARY KEY,
  slug VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  display_order INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_board_category_updated
BEFORE UPDATE ON board_category FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 보드
CREATE TABLE IF NOT EXISTS board (
  id BIGSERIAL PRIMARY KEY,
  category_id BIGINT NOT NULL REFERENCES board_category(id) ON DELETE CASCADE,
  slug VARCHAR(64) NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  allow_images BOOLEAN NOT NULL DEFAULT TRUE,
  allow_files  BOOLEAN NOT NULL DEFAULT TRUE,
  display_order INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (category_id, slug)
);
CREATE INDEX IF NOT EXISTS idx_board_category ON board(category_id);
CREATE TRIGGER trg_board_updated
BEFORE UPDATE ON board FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 태그
CREATE TABLE IF NOT EXISTS tag (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 게시글
CREATE TABLE IF NOT EXISTS post (
  id BIGSERIAL PRIMARY KEY,
  board_id BIGINT NOT NULL REFERENCES board(id) ON DELETE CASCADE,
  author_id BIGINT NOT NULL,         -- FK는 V02에서 보강(Users 생성 후)
  title VARCHAR(200) NOT NULL,
  slug VARCHAR(128),
  content_md   TEXT,
  content_html TEXT,
  status       post_status NOT NULL DEFAULT 'published',
  visibility   visibility  NOT NULL DEFAULT 'public',
  lang         VARCHAR(10) NOT NULL DEFAULT 'ko',
  is_pinned    BOOLEAN NOT NULL DEFAULT FALSE,
  pin_until    TIMESTAMPTZ,
  like_count     INTEGER NOT NULL DEFAULT 0,
  bookmark_count INTEGER NOT NULL DEFAULT 0,
  comment_count  INTEGER NOT NULL DEFAULT 0,
  view_count     INTEGER NOT NULL DEFAULT 0,
  hot_score DOUBLE PRECISION NOT NULL DEFAULT 0,
  published_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at  TIMESTAMPTZ,
  CONSTRAINT uq_post_slug UNIQUE (board_id, slug)
);
CREATE INDEX IF NOT EXISTS idx_post_board ON post(board_id);
CREATE INDEX IF NOT EXISTS idx_post_published ON post((published_at) DESC) WHERE status='published' AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_post_hot ON post((hot_score) DESC) WHERE status='published' AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_post_pinned ON post(is_pinned) WHERE is_pinned = TRUE AND (pin_until IS NULL OR pin_until > now());
CREATE INDEX IF NOT EXISTS idx_post_visibility ON post(visibility);
CREATE TRIGGER trg_post_updated
BEFORE UPDATE ON post FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 글-태그 매핑
CREATE TABLE IF NOT EXISTS post_tag (
  post_id BIGINT NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  tag_id  BIGINT NOT NULL REFERENCES tag(id)  ON DELETE RESTRICT,
  PRIMARY KEY (post_id, tag_id)
);
CREATE INDEX IF NOT EXISTS idx_post_tag_tag ON post_tag(tag_id);

-- 첨부
CREATE TABLE IF NOT EXISTS post_attachment (
  id BIGSERIAL PRIMARY KEY,
  post_id BIGINT NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  file_name  TEXT NOT NULL,
  mime_type  VARCHAR(255),
  file_size  BIGINT,
  storage_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_attachment_post ON post_attachment(post_id);

-- 이미지
CREATE TABLE IF NOT EXISTS post_image (
  id BIGSERIAL PRIMARY KEY,
  post_id BIGINT NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  is_thumbnail BOOLEAN NOT NULL DEFAULT FALSE,
  alt_text TEXT, storage_key TEXT NOT NULL,
  width INT, height INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_image_post ON post_image(post_id);
CREATE INDEX IF NOT EXISTS idx_image_thumb ON post_image(post_id, is_thumbnail) WHERE is_thumbnail = TRUE;

-- 반응
CREATE TABLE IF NOT EXISTS post_reaction (
  post_id BIGINT NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL,
  kind VARCHAR(16) NOT NULL DEFAULT 'like',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id, kind)
);
CREATE INDEX IF NOT EXISTS idx_reaction_user ON post_reaction(user_id);

-- 북마크
CREATE TABLE IF NOT EXISTS post_bookmark (
  post_id BIGINT NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_bookmark_user ON post_bookmark(user_id);

-- 조회
CREATE TABLE IF NOT EXISTS post_view (
  post_id BIGINT NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  viewer_id BIGINT,      -- Users FK는 V02에서 보강
  view_key  TEXT,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_view_post ON post_view(post_id);
CREATE INDEX IF NOT EXISTS idx_view_key ON post_view(post_id, viewer_id, view_key);

-- 댓글
CREATE TABLE IF NOT EXISTS comment (
  id BIGSERIAL PRIMARY KEY,
  post_id   BIGINT NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  author_id BIGINT NOT NULL,   -- Users FK는 V02에서 보강
  parent_id BIGINT REFERENCES comment(id) ON DELETE CASCADE,
  content_md   TEXT NOT NULL,
  content_html TEXT,
  like_count INTEGER NOT NULL DEFAULT 0,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_comment_post ON comment(post_id);
CREATE INDEX IF NOT EXISTS idx_comment_parent ON comment(parent_id);
CREATE TRIGGER trg_comment_updated
BEFORE UPDATE ON comment FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 댓글 반응
CREATE TABLE IF NOT EXISTS comment_reaction (
  comment_id BIGINT NOT NULL REFERENCES comment(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL,
  kind VARCHAR(16) NOT NULL DEFAULT 'like',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (comment_id, user_id, kind)
);
CREATE INDEX IF NOT EXISTS idx_comment_reaction_user ON comment_reaction(user_id);

-- 개인 즐겨찾기
CREATE TABLE IF NOT EXISTS user_favorite_board (
  user_id BIGINT NOT NULL,
  board_id BIGINT NOT NULL REFERENCES board(id) ON DELETE CASCADE,
  display_order INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, board_id)
);
CREATE INDEX IF NOT EXISTS idx_fav_board_user ON user_favorite_board(user_id);

CREATE TABLE IF NOT EXISTS user_favorite_category (
  user_id BIGINT NOT NULL,
  category_id BIGINT NOT NULL REFERENCES board_category(id) ON DELETE CASCADE,
  display_order INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category_id)
);
CREATE INDEX IF NOT EXISTS idx_fav_cat_user ON user_favorite_category(user_id);

-- 인기글 뷰
CREATE OR REPLACE VIEW v_post_engagement_last7d AS
SELECT
  p.id, p.board_id, p.title, p.published_at,
  p.like_count, p.bookmark_count, p.comment_count, p.view_count,
  GREATEST(0, 8 - COALESCE(EXTRACT(EPOCH FROM (now() - p.published_at))/86400.0, 8)) AS recency_weight,
  (p.like_count*3 + p.bookmark_count*4 + p.comment_count*5 + LOG(10, p.view_count + 1)) AS base_score
FROM post p
WHERE p.status='published' AND p.deleted_at IS NULL
  AND p.published_at >= now() - INTERVAL '7 days';
