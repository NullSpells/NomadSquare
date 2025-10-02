-- 초기 공통 준비물: 스키마/확장/공용 함수/공용 enum
CREATE SCHEMA IF NOT EXISTS nsq;
SET search_path TO nsq, public;

-- 확장 (대소문자 무시 이메일/아이디)
CREATE EXTENSION IF NOT EXISTS citext;

-- updated_at 자동 세팅 트리거 함수
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

-- 공용 ENUM들 생성 (존재시 스킵)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='post_status') THEN
    CREATE TYPE post_status AS ENUM ('draft','published','archived');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='visibility') THEN
    CREATE TYPE visibility AS ENUM ('public','followers','private');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='user_status') THEN
    CREATE TYPE user_status AS ENUM ('active','suspended','deleted');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='role') THEN
    CREATE TYPE role AS ENUM ('user','moderator','admin');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='auth_provider') THEN
    CREATE TYPE auth_provider AS ENUM ('password','google','apple','github','kakao','naver');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='notify_channel') THEN
    CREATE TYPE notify_channel AS ENUM ('email','push','inapp');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='rbac_scope') THEN
    CREATE TYPE rbac_scope AS ENUM ('global','category','board','post');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='admin_target') THEN
    CREATE TYPE admin_target AS ENUM ('user','post','comment','board','category');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='report_status') THEN
    CREATE TYPE report_status AS ENUM ('open','triaged','in_progress','resolved','dismissed');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='sanction_kind') THEN
    CREATE TYPE sanction_kind AS ENUM ('warn','mute','shadowban','suspend','ban');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='action_kind') THEN
    CREATE TYPE action_kind AS ENUM (
      'create','update','delete','restore','hide','unhide','lock','unlock','assign','reassign','close','reopen'
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='export_status') THEN
    CREATE TYPE export_status AS ENUM ('requested','processing','ready','failed','expired');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='market_status') THEN
    CREATE TYPE market_status AS ENUM ('listed','reserved','sold','hidden');
  END IF;
END$$;
