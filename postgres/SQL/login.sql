-- 1. user 테이블
CREATE TABLE user (
    user_id            SERIAL PRIMARY KEY,
    user_type          VARCHAR(20) NOT NULL CHECK (user_type IN ('guest', 'member', 'trainer', 'center_manager', 'admin')),
    email              VARCHAR(255),
    password           VARCHAR(255),
    name               VARCHAR(100) NOT NULL,
    phone              VARCHAR(20),
    status             VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DORMANT', 'WITHDRAWN')),
    last_login_at      TIMESTAMP,
    rmrk               VARCHAR(255), 
    use_yn             CHAR(1) DEFAULT 'Y' CHECK (use_yn IN ('Y', 'N')),
    ins_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    ins_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    ins_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    upd_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    upd_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_user_email_unique
ON user(email)
WHERE user_type IN ('member', 'trainer', 'center_manager', 'admin');

-- 2. role 테이블
CREATE TABLE role (
    role_id            SERIAL PRIMARY KEY,
    role_name          VARCHAR(30) UNIQUE NOT NULL CHECK (role_name IN ('guest', 'member', 'trainer', 'center_manager', 'admin')),
    rmrk               VARCHAR(255),
    use_yn             CHAR(1) DEFAULT 'Y' CHECK (use_yn IN ('Y', 'N')),
    ins_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    ins_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    ins_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    upd_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    upd_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. user_role 테이블 (FK 대신 NOT NULL, CHECK만 사용)
CREATE TABLE user_role (
    user_id            INTEGER NOT NULL,
    role_id            INTEGER NOT NULL,
    rmrk               VARCHAR(255),
    use_yn             CHAR(1) DEFAULT 'Y' CHECK (use_yn IN ('Y', 'N')),
    ins_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    ins_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    ins_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    upd_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    upd_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
    -- FK는 선언하지 않음. 무결성은 운영·로직에서 관리
);

-- 4. social_account 테이블
CREATE TABLE social_account (
    social_account_id  SERIAL PRIMARY KEY,
    user_id            INTEGER NOT NULL,
    provider           VARCHAR(50) NOT NULL,      -- ex) kakao, google 등
    provider_user_id   VARCHAR(255) NOT NULL,
    email              VARCHAR(255),
    profile_img        VARCHAR(255),
    rmrk               VARCHAR(255),
    use_yn             CHAR(1) DEFAULT 'Y' CHECK (use_yn IN ('Y', 'N')),
    ins_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    ins_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    ins_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    upd_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    upd_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (provider, provider_user_id)
    -- FK 없이 user_id만 존재, 무결성은 애플리케이션에서 보장
);

-- 5. trainer_profile 테이블
CREATE TABLE trainer_profile (
    user_id            INTEGER PRIMARY KEY,
    license            VARCHAR(255),
    career_years       INTEGER,
    profile_img        VARCHAR(255),
    intro              TEXT,
    rmrk               VARCHAR(255),
    use_yn             CHAR(1) DEFAULT 'Y' CHECK (use_yn IN ('Y', 'N')),
    ins_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    ins_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    ins_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    upd_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    upd_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    -- FK 없이 user_id만 존재
);

-- 6. center_manager_profile 테이블
CREATE TABLE center_manager_profile (
    user_id            INTEGER PRIMARY KEY,
    center_id          INTEGER,
    manager_level      VARCHAR(50),
    rmrk               VARCHAR(255),
    use_yn             CHAR(1) DEFAULT 'Y' CHECK (use_yn IN ('Y', 'N')),
    ins_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    ins_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    ins_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    upd_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    upd_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    -- FK 없이 user_id만 존재
);

-- 7. comm_cd_mst (공통코드 마스터)
CREATE TABLE comm_cd_mst (
    comm_cd_grp        VARCHAR(20) PRIMARY KEY,
    comm_cd_grp_nm     VARCHAR(100) NOT NULL,
    rmrk               VARCHAR(255),
    use_yn             CHAR(1) DEFAULT 'Y' CHECK (use_yn IN ('Y', 'N')),
    ord_no             INTEGER DEFAULT 1,
    ins_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    ins_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    ins_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    upd_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    upd_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. comm_cd_dtl (공통코드 상세)
CREATE TABLE comm_cd_dtl (
    comm_cd_grp        VARCHAR(20) NOT NULL,
    comm_cd            VARCHAR(20) NOT NULL,
    comm_cd_nm         VARCHAR(100) NOT NULL,
    desc_txt           VARCHAR(255),
    rmrk               VARCHAR(255),
    use_yn             CHAR(1) DEFAULT 'Y' CHECK (use_yn IN ('Y', 'N')),
    ord_no             INTEGER DEFAULT 1,
    ins_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    ins_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    ins_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_id             VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    upd_ip             VARCHAR(40) NOT NULL DEFAULT '127.0.0.1',
    upd_dt             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (comm_cd_grp, comm_cd)
    -- FK 없이 comm_cd_grp만 존재, 무결성은 코드/앱에서
);

-- 9. role 기본 데이터 입력
INSERT INTO role (role_name) VALUES
  ('guest'), ('member'), ('trainer'), ('center_manager'), ('admin');
