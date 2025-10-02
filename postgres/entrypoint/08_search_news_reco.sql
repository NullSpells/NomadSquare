SET search_path TO nsq, public;

-- 검색 로그
CREATE TABLE IF NOT EXISTS search_query_log (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  q TEXT NOT NULL,
  source VARCHAR(32) NOT NULL DEFAULT 'global',
  results INT,
  clicked_entity TEXT,
  clicked_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- FTS (초도 1회)
ALTER TABLE IF NOT EXISTS post ADD COLUMN IF NOT EXISTS fts tsvector;

CREATE OR REPLACE FUNCTION post_fts_update() RETURNS trigger AS $$
BEGIN
  NEW.fts := to_tsvector('simple', coalesce(NEW.title,'') || ' ' || coalesce(NEW.content_md,''));
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_post_fts_insupd ON post;
CREATE TRIGGER trg_post_fts_insupd
BEFORE INSERT OR UPDATE OF title, content_md ON post
FOR EACH ROW EXECUTE FUNCTION post_fts_update();

-- 초기 백필
UPDATE post p SET fts = to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(content_md,''))
WHERE p.fts IS NULL;

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_post_fts ON post USING GIN(fts);

-- 뉴스
CREATE TABLE IF NOT EXISTS news_source (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  feed_url TEXT, country_code VARCHAR(2), lang VARCHAR(10),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS news_article (
  id BIGSERIAL PRIMARY KEY,
  source_id BIGINT REFERENCES news_source(id) ON DELETE SET NULL,
  ext_id TEXT, url TEXT, title TEXT,
  content_raw TEXT, lang VARCHAR(10) NOT NULL,
  author TEXT, published_at TIMESTAMPTZ,
  hash CHAR(40),
  created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (source_id, ext_id)
);
CREATE TABLE IF NOT EXISTS news_translation (
  article_id BIGINT PRIMARY KEY REFERENCES news_article(id) ON DELETE CASCADE,
  target_lang VARCHAR(10) NOT NULL DEFAULT 'ko',
  title_trans TEXT, content_trans TEXT,
  provider VARCHAR(64), translated_at TIMESTAMPTZ DEFAULT now()
);

-- 개인화(관심사/국가/피드 캐시)
CREATE TABLE IF NOT EXISTS interest_tag (
  id BIGSERIAL PRIMARY KEY, name VARCHAR(64) UNIQUE NOT NULL
);
CREATE TABLE IF NOT EXISTS user_interest (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tag_id  BIGINT NOT NULL REFERENCES interest_tag(id) ON DELETE CASCADE,
  weight REAL NOT NULL DEFAULT 1.0,
  PRIMARY KEY (user_id, tag_id)
);
CREATE TABLE IF NOT EXISTS user_geo_preference (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  country_code VARCHAR(2) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS user_feed_cache (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_type VARCHAR(16) NOT NULL,
  item_id BIGINT NOT NULL,
  score DOUBLE PRECISION NOT NULL,
  ranked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, item_type, item_id)
);
