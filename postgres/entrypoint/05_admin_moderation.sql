SET search_path TO nsq, public;

-- 신고
CREATE TABLE IF NOT EXISTS moderation_report (
  id BIGSERIAL PRIMARY KEY,
  reporter_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_type admin_target NOT NULL,
  target_id BIGINT NOT NULL,
  reason_code VARCHAR(64),
  reason_text TEXT,
  status report_status NOT NULL DEFAULT 'open',
  assigned_admin_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  UNIQUE (reporter_id, target_type, target_id, COALESCE(reason_code,''))
);
CREATE INDEX IF NOT EXISTS idx_report_target ON moderation_report(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_report_status ON moderation_report(status);
CREATE INDEX IF NOT EXISTS idx_report_assignee ON moderation_report(assigned_admin_id);
CREATE TRIGGER trg_report_updated BEFORE UPDATE ON moderation_report FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 케이스 & 매핑
CREATE TABLE IF NOT EXISTS moderation_case (
  id BIGSERIAL PRIMARY KEY,
  opener_admin_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  target_type admin_target NOT NULL,
  target_id BIGINT NOT NULL,
  summary TEXT,
  status report_status NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_case_target ON moderation_case(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_case_status ON moderation_case(status);
CREATE TRIGGER trg_case_updated BEFORE UPDATE ON moderation_case FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS moderation_case_report (
  case_id BIGINT NOT NULL REFERENCES moderation_case(id) ON DELETE CASCADE,
  report_id BIGINT NOT NULL REFERENCES moderation_report(id) ON DELETE CASCADE,
  PRIMARY KEY (case_id, report_id)
);

-- 제재
CREATE TABLE IF NOT EXISTS user_sanction (
  id BIGSERIAL PRIMARY KEY,
  target_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind sanction_kind NOT NULL,
  scope rbac_scope NOT NULL DEFAULT 'global',
  scope_id BIGINT,
  reason_admin TEXT,
  reason_public TEXT,
  issued_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ends_at TIMESTAMPTZ,
  is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((scope='global' AND scope_id IS NULL) OR (scope<>'global' AND scope_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_sanction_user ON user_sanction(target_user_id);
CREATE INDEX IF NOT EXISTS idx_sanction_active ON user_sanction(target_user_id, kind, is_revoked, ends_at);
CREATE TRIGGER trg_sanction_updated BEFORE UPDATE ON user_sanction FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 강제 조치 로그
CREATE TABLE IF NOT EXISTS admin_action_log (
  id BIGSERIAL PRIMARY KEY,
  admin_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  target_type admin_target NOT NULL,
  target_id BIGINT NOT NULL,
  action action_kind NOT NULL,
  reason TEXT,
  before_data JSONB,
  after_data  JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_admin_action_target ON admin_action_log(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_admin_action_admin ON admin_action_log(admin_id);

-- 관리자 노트
CREATE TABLE IF NOT EXISTS admin_note (
  id BIGSERIAL PRIMARY KEY,
  author_admin_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  target_type admin_target NOT NULL,
  target_id BIGINT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_admin_note_target ON admin_note(target_type, target_id);

-- 설정/피처 플래그
CREATE TABLE IF NOT EXISTS system_config (
  key VARCHAR(128) PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS feature_flag (
  key VARCHAR(128) PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  rules JSONB,
  description TEXT,
  updated_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 배치 작업 & 실행 이력
CREATE TABLE IF NOT EXISTS admin_job (
  id BIGSERIAL PRIMARY KEY,
  slug VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  schedule_cron VARCHAR(64),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_admin_job_updated BEFORE UPDATE ON admin_job FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS admin_job_run (
  id BIGSERIAL PRIMARY KEY,
  job_id BIGINT NOT NULL REFERENCES admin_job(id) ON DELETE CASCADE,
  started_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ,
  success BOOLEAN,
  log TEXT
);
CREATE INDEX IF NOT EXISTS idx_job_run_job ON admin_job_run(job_id);

-- 데이터 내보내기/삭제 요청
CREATE TABLE IF NOT EXISTS user_data_export_request (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind VARCHAR(32) NOT NULL DEFAULT 'export',
  status export_status NOT NULL DEFAULT 'requested',
  storage_key TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  error_msg TEXT
);
CREATE INDEX IF NOT EXISTS idx_export_user ON user_data_export_request(user_id, status);

-- 가장중 로그
CREATE TABLE IF NOT EXISTS admin_impersonation_log (
  id BIGSERIAL PRIMARY KEY,
  admin_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_impersonation_admin ON admin_impersonation_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_impersonation_target ON admin_impersonation_log(target_user_id);

-- 엔터티 변경 이력
CREATE TABLE IF NOT EXISTS entity_change_log (
  id BIGSERIAL PRIMARY KEY,
  table_name VARCHAR(128) NOT NULL,
  entity_id BIGINT NOT NULL,
  changed_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
  action action_kind NOT NULL,
  before_data JSONB,
  after_data  JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_entity_change ON entity_change_log(table_name, entity_id);

-- 폴리모픽 타깃 무결성 보조 트리거
CREATE OR REPLACE FUNCTION admin_target_fk_check()
RETURNS trigger AS $$
DECLARE c INT;
BEGIN
  IF NEW.target_type='user'     THEN SELECT COUNT(*) INTO c FROM users WHERE id=NEW.target_id;
  ELSIF NEW.target_type='post'  THEN SELECT COUNT(*) INTO c FROM post WHERE id=NEW.target_id;
  ELSIF NEW.target_type='comment' THEN SELECT COUNT(*) INTO c FROM comment WHERE id=NEW.target_id;
  ELSIF NEW.target_type='board' THEN SELECT COUNT(*) INTO c FROM board WHERE id=NEW.target_id;
  ELSIF NEW.target_type='category' THEN SELECT COUNT(*) INTO c FROM board_category WHERE id=NEW.target_id;
  END IF;
  IF COALESCE(c,0)=0 THEN RAISE EXCEPTION 'admin target %:% not found', NEW.target_type, NEW.target_id; END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_report_target_fk ON moderation_report;
CREATE TRIGGER trg_report_target_fk BEFORE INSERT OR UPDATE ON moderation_report
FOR EACH ROW EXECUTE FUNCTION admin_target_fk_check();

DROP TRIGGER IF EXISTS trg_case_target_fk ON moderation_case;
CREATE TRIGGER trg_case_target_fk BEFORE INSERT OR UPDATE ON moderation_case
FOR EACH ROW EXECUTE FUNCTION admin_target_fk_check();

DROP TRIGGER IF EXISTS trg_action_target_fk ON admin_action_log;
CREATE TRIGGER trg_action_target_fk BEFORE INSERT OR UPDATE ON admin_action_log
FOR EACH ROW EXECUTE FUNCTION admin_target_fk_check();

DROP TRIGGER IF EXISTS trg_note_target_fk ON admin_note;
CREATE TRIGGER trg_note_target_fk BEFORE INSERT OR UPDATE ON admin_note
FOR EACH ROW EXECUTE FUNCTION admin_target_fk_check();

-- 운영 보조 뷰
CREATE OR REPLACE VIEW v_report_summary AS
SELECT target_type,
  COUNT(*) FILTER (WHERE status='open')        AS open_cnt,
  COUNT(*) FILTER (WHERE status='triaged')     AS triaged_cnt,
  COUNT(*) FILTER (WHERE status='in_progress') AS in_progress_cnt
FROM moderation_report GROUP BY target_type;

CREATE OR REPLACE VIEW v_moderation_workload AS
SELECT mr.assigned_admin_id AS admin_id,
       COALESCE(up.display_name, u.username) AS admin_name,
       COUNT(*) FILTER (WHERE mr.status='open')        AS open_cnt,
       COUNT(*) FILTER (WHERE mr.status='in_progress') AS in_progress_cnt
FROM moderation_report mr
LEFT JOIN users u ON u.id = mr.assigned_admin_id
LEFT JOIN user_profile up ON up.user_id = u.id
GROUP BY mr.assigned_admin_id, up.display_name, u.username;

CREATE OR REPLACE VIEW v_active_sanctions AS
SELECT * FROM user_sanction s
WHERE is_revoked = FALSE AND (s.ends_at IS NULL OR s.ends_at > now());
