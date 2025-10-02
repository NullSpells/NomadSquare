SET search_path TO nsq, public;

-- 권한 사전
CREATE TABLE IF NOT EXISTS rbac_permission (
  id BIGSERIAL PRIMARY KEY,
  resource VARCHAR(64) NOT NULL,
  action   VARCHAR(64) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (resource, action)
);
CREATE INDEX IF NOT EXISTS idx_perm_resource ON rbac_permission(resource);
CREATE TRIGGER trg_perm_updated BEFORE UPDATE ON rbac_permission FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 역할
CREATE TABLE IF NOT EXISTS rbac_role (
  id BIGSERIAL PRIMARY KEY,
  slug VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_role_updated BEFORE UPDATE ON rbac_role FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 역할-권한
CREATE TABLE IF NOT EXISTS rbac_role_permission (
  role_id BIGINT NOT NULL REFERENCES rbac_role(id) ON DELETE CASCADE,
  permission_id BIGINT NOT NULL REFERENCES rbac_permission(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);
CREATE INDEX IF NOT EXISTS idx_roleperm_perm ON rbac_role_permission(permission_id);

-- 그룹/멤버/역할부여
CREATE TABLE IF NOT EXISTS rbac_group (
  id BIGSERIAL PRIMARY KEY,
  slug VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_group_updated BEFORE UPDATE ON rbac_group FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS rbac_group_member (
  group_id BIGINT NOT NULL REFERENCES rbac_group(id) ON DELETE CASCADE,
  user_id  BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_group_member_user ON rbac_group_member(user_id);

CREATE TABLE IF NOT EXISTS rbac_group_role (
  group_id BIGINT NOT NULL REFERENCES rbac_group(id) ON DELETE CASCADE,
  role_id  BIGINT NOT NULL REFERENCES rbac_role(id)  ON DELETE CASCADE,
  scope    rbac_scope NOT NULL DEFAULT 'global',
  scope_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, role_id, scope, COALESCE(scope_id, 0)),
  CHECK ((scope='global' AND scope_id IS NULL) OR (scope<>'global' AND scope_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_group_role_scope ON rbac_group_role(scope, scope_id);

-- 사용자 직접 역할 부여
CREATE TABLE IF NOT EXISTS rbac_user_role (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id BIGINT NOT NULL REFERENCES rbac_role(id) ON DELETE CASCADE,
  scope   rbac_scope NOT NULL DEFAULT 'global',
  scope_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id, scope, COALESCE(scope_id, 0)),
  CHECK ((scope='global' AND scope_id IS NULL) OR (scope<>'global' AND scope_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_user_role_user ON rbac_user_role(user_id);
CREATE INDEX IF NOT EXISTS idx_user_role_scope ON rbac_user_role(scope, scope_id);

-- 스코프 무결성 보조 트리거
CREATE OR REPLACE FUNCTION rbac_scope_fk_check()
RETURNS trigger AS $$
DECLARE c INT;
BEGIN
  IF NEW.scope='global' THEN RETURN NEW; END IF;
  IF NEW.scope='category' THEN SELECT COUNT(*) INTO c FROM board_category WHERE id=NEW.scope_id;
  ELSIF NEW.scope='board' THEN SELECT COUNT(*) INTO c FROM board WHERE id=NEW.scope_id;
  ELSIF NEW.scope='post' THEN SELECT COUNT(*) INTO c FROM post WHERE id=NEW.scope_id;
  END IF;
  IF COALESCE(c,0)=0 THEN RAISE EXCEPTION 'RBAC scope_id % not found for scope %', NEW.scope_id, NEW.scope; END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_role_scope_fk ON rbac_user_role;
CREATE TRIGGER trg_user_role_scope_fk BEFORE INSERT OR UPDATE ON rbac_user_role
FOR EACH ROW EXECUTE FUNCTION rbac_scope_fk_check();

DROP TRIGGER IF EXISTS trg_group_role_scope_fk ON rbac_group_role;
CREATE TRIGGER trg_group_role_scope_fk BEFORE INSERT OR UPDATE ON rbac_group_role
FOR EACH ROW EXECUTE FUNCTION rbac_scope_fk_check();

-- 유효 권한 뷰 + 헬퍼
CREATE OR REPLACE VIEW v_effective_permissions AS
WITH user_roles AS (
  SELECT ur.user_id, ur.role_id, ur.scope, ur.scope_id FROM rbac_user_role ur
  UNION ALL
  SELECT gm.user_id, gr.role_id, gr.scope, gr.scope_id
  FROM rbac_group_member gm JOIN rbac_group_role gr ON gr.group_id=gm.group_id
),
dedup_roles AS (SELECT DISTINCT user_id, role_id, scope, scope_id FROM user_roles),
role_perms AS (
  SELECT dr.user_id, rp.permission_id, dr.scope, dr.scope_id
  FROM dedup_roles dr JOIN rbac_role_permission rp ON rp.role_id=dr.role_id
)
SELECT rp.user_id, p.resource, p.action, rp.scope, rp.scope_id, p.id AS permission_id
FROM role_perms rp JOIN rbac_permission p ON p.id=rp.permission_id;

CREATE OR REPLACE FUNCTION has_permission(
  p_user_id BIGINT, p_resource VARCHAR, p_action VARCHAR, p_scope rbac_scope, p_scope_id BIGINT
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE ok BOOLEAN;
BEGIN
  SELECT TRUE INTO ok FROM v_effective_permissions v
  WHERE v.user_id=p_user_id AND v.resource=p_resource AND v.action=p_action
    AND ((v.scope=p_scope AND COALESCE(v.scope_id,0)=COALESCE(p_scope_id,0)) OR v.scope='global')
  LIMIT 1;
  RETURN COALESCE(ok,FALSE);
END $$;
