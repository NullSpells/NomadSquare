SET search_path TO nsq, public;

CREATE TABLE IF NOT EXISTS legal_document (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(64) NOT NULL,
  version VARCHAR(32) NOT NULL,
  title VARCHAR(200) NOT NULL,
  body_md TEXT NOT NULL,
  locale VARCHAR(10) NOT NULL DEFAULT 'ko',
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (code, version, locale)
);

CREATE TABLE IF NOT EXISTS user_consent (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  document_id BIGINT NOT NULL REFERENCES legal_document(id) ON DELETE CASCADE,
  granted BOOLEAN NOT NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, document_id)
);
