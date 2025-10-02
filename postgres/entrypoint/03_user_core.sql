SET search_path TO nsq, public;

-- 사용자 기본
CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  email CITEXT,
  username CITEXT,
  password_hash TEXT,
  password_algo  VARCHAR(64),
  password_updated_at TIMESTAMPTZ,
  status user_status NOT NULL DEFAULT 'active',
  roles  role[] NOT NULL DEFAULT ARRAY['user']::role[],
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email_ci ON users((lower(email))) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username_ci ON users((lower(username))) WHERE username IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_roles_gin ON users USING GIN(roles);
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 프로필
CREATE TABLE IF NOT EXISTS user_profile (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name VARCHAR(100),
  bio TEXT,
  avatar_key TEXT,
  cover_key  TEXT,
  website_url TEXT,
  location VARCHAR(120),
  lang VARCHAR(10) NOT NULL DEFAULT 'ko',
  timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Seoul',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_user_profile_updated BEFORE UPDATE ON user_profile FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 소셜 계정
CREATE TABLE IF NOT EXISTS user_auth_oauth (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider auth_provider NOT NULL,
  provider_user_id TEXT NOT NULL,
  email_from_provider CITEXT,
  access_token  TEXT,
  refresh_token TEXT,
  token_scopes  TEXT,
  token_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_user_id)
);
CREATE INDEX IF NOT EXISTS idx_oauth_user ON user_auth_oauth(user_id);
CREATE TRIGGER trg_user_oauth_updated BEFORE UPDATE ON user_auth_oauth FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 설정
CREATE TABLE IF NOT EXISTS user_settings (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  dark_mode BOOLEAN NOT NULL DEFAULT FALSE,
  email_notify_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  push_notify_enabled  BOOLEAN NOT NULL DEFAULT TRUE,
  inapp_notify_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  notify_newsletter    BOOLEAN NOT NULL DEFAULT FALSE,
  notify_comment_reply BOOLEAN NOT NULL DEFAULT TRUE,
  notify_post_reaction BOOLEAN NOT NULL DEFAULT TRUE,
  two_factor_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
  web_lang VARCHAR(10) DEFAULT 'ko',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_user_settings_updated BEFORE UPDATE ON user_settings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 팔로우/차단
CREATE TABLE IF NOT EXISTS user_follow (
  follower_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id),
  CHECK (follower_id <> followee_id)
);
CREATE INDEX IF NOT EXISTS idx_follow_followee ON user_follow(followee_id);

CREATE TABLE IF NOT EXISTS user_block (
  blocker_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_block_blocked ON user_block(blocked_id);

-- 디바이스/알림/로그/토큰
CREATE TABLE IF NOT EXISTS user_device (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform VARCHAR(20) NOT NULL,
  device_id TEXT,
  push_token TEXT,
  last_seen_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, platform, COALESCE(device_id, ''))
);
CREATE INDEX IF NOT EXISTS idx_user_device_user ON user_device(user_id);
CREATE TRIGGER trg_user_device_updated BEFORE UPDATE ON user_device FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS notification (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel notify_channel NOT NULL DEFAULT 'inapp',
  topic VARCHAR(64) NOT NULL,
  title VARCHAR(200),
  body TEXT,
  link_url TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notification_user ON notification(user_id, is_read);

CREATE TABLE IF NOT EXISTS user_login_activity (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  provider auth_provider,
  ip_addr INET,
  user_agent TEXT,
  success BOOLEAN NOT NULL DEFAULT TRUE,
  reason TEXT,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_login_user_time ON user_login_activity(user_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS user_verification_token (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose VARCHAR(32) NOT NULL,
  token TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (purpose, token)
);
CREATE INDEX IF NOT EXISTS idx_verif_user ON user_verification_token(user_id, purpose);

-- ===== Board ↔ Users FK 보강 (초도 1회) =====
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_post_author') THEN
    ALTER TABLE nsq.post
      ADD CONSTRAINT fk_post_author
      FOREIGN KEY (author_id) REFERENCES nsq.users(id) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_comment_author') THEN
    ALTER TABLE nsq.comment
      ADD CONSTRAINT fk_comment_author
      FOREIGN KEY (author_id) REFERENCES nsq.users(id) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_post_reaction_user') THEN
    ALTER TABLE nsq.post_reaction
      ADD CONSTRAINT fk_post_reaction_user
      FOREIGN KEY (user_id) REFERENCES nsq.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_post_bookmark_user') THEN
    ALTER TABLE nsq.post_bookmark
      ADD CONSTRAINT fk_post_bookmark_user
      FOREIGN KEY (user_id) REFERENCES nsq.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_comment_reaction_user') THEN
    ALTER TABLE nsq.comment_reaction
      ADD CONSTRAINT fk_comment_reaction_user
      FOREIGN KEY (user_id) REFERENCES nsq.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_post_view_viewer') THEN
    ALTER TABLE nsq.post_view
      ADD CONSTRAINT fk_post_view_viewer
      FOREIGN KEY (viewer_id) REFERENCES nsq.users(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_user_fav_board_user') THEN
    ALTER TABLE nsq.user_favorite_board
      ADD CONSTRAINT fk_user_fav_board_user
      FOREIGN KEY (user_id) REFERENCES nsq.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_user_fav_category_user') THEN
    ALTER TABLE nsq.user_favorite_category
      ADD CONSTRAINT fk_user_fav_category_user
      FOREIGN KEY (user_id) REFERENCES nsq.users(id) ON DELETE CASCADE;
  END IF;
END$$;
