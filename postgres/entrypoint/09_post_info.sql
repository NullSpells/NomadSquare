SET search_path TO nsq, public;

-- 거래
CREATE TABLE IF NOT EXISTS market_listing (
  id BIGSERIAL PRIMARY KEY,
  seller_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  price NUMERIC(12,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'KRW',
  description_md TEXT,
  location_text VARCHAR(200),
  status market_status NOT NULL DEFAULT 'listed',
  created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS market_image (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL REFERENCES market_listing(id) ON DELETE CASCADE,
  storage_key TEXT NOT NULL,
  is_cover BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE IF NOT EXISTS market_favorite (
  listing_id BIGINT NOT NULL REFERENCES market_listing(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (listing_id, user_id)
);
CREATE TABLE IF NOT EXISTS market_offer (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL REFERENCES market_listing(id) ON DELETE CASCADE,
  buyer_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  offer_price NUMERIC(12,2) NOT NULL,
  message TEXT, created_at TIMESTAMPTZ DEFAULT now()
);

-- DM
CREATE TABLE IF NOT EXISTS dm_thread ( id BIGSERIAL PRIMARY KEY, created_at TIMESTAMPTZ DEFAULT now() );
CREATE TABLE IF NOT EXISTS dm_participant (
  thread_id BIGINT NOT NULL REFERENCES dm_thread(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (thread_id, user_id)
);
CREATE TABLE IF NOT EXISTS dm_message (
  id BIGSERIAL PRIMARY KEY,
  thread_id BIGINT NOT NULL REFERENCES dm_thread(id) ON DELETE CASCADE,
  sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT, created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS dm_read (
  thread_id BIGINT NOT NULL REFERENCES dm_thread(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_read_message_id BIGINT,
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (thread_id, user_id)
);

-- 채팅
CREATE TABLE IF NOT EXISTS chat_room (
  id BIGSERIAL PRIMARY KEY,
  slug VARCHAR(64) UNIQUE,
  name VARCHAR(100),
  is_public BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS chat_member (
  room_id BIGINT NOT NULL REFERENCES chat_room(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);
CREATE TABLE IF NOT EXISTS chat_message (
  id BIGSERIAL PRIMARY KEY,
  room_id BIGINT NOT NULL REFERENCES chat_room(id) ON DELETE CASCADE,
  sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT, created_at TIMESTAMPTZ DEFAULT now()
);

-- 지오
CREATE TABLE IF NOT EXISTS geo_country (
  code VARCHAR(2) PRIMARY KEY,
  name_ko VARCHAR(100),
  name_en VARCHAR(100)
);
CREATE TABLE IF NOT EXISTS board_country (
  board_id BIGINT NOT NULL REFERENCES board(id) ON DELETE CASCADE,
  country_code VARCHAR(2) NOT NULL REFERENCES geo_country(code) ON DELETE CASCADE,
  PRIMARY KEY (board_id, country_code)
);

-- 정보형 메타
CREATE TABLE IF NOT EXISTS post_job_meta (
  post_id BIGINT PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
  company VARCHAR(200), salary_text VARCHAR(100),
  location_text VARCHAR(200), employment_type VARCHAR(32)
);
CREATE TABLE IF NOT EXISTS post_travel_meta (
  post_id BIGINT PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
  country_code VARCHAR(2), city VARCHAR(100), best_season VARCHAR(64)
);
CREATE TABLE IF NOT EXISTS post_hotel_meta (
  post_id BIGINT PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
  address TEXT, price_range VARCHAR(64), contact TEXT
);
CREATE TABLE IF NOT EXISTS post_event_meta (
  post_id BIGINT PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
  event_start TIMESTAMPTZ, event_end TIMESTAMPTZ, venue TEXT
);
CREATE TABLE IF NOT EXISTS post_deal_meta (
  post_id BIGINT PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
  price_before NUMERIC(12,2), price_after NUMERIC(12,2),
  deal_expire TIMESTAMPTZ, link_url TEXT
);

-- ================================================
-- Share / Rent Room (Housing) for Working-Holiday
-- ================================================
SET search_path TO nsq, public;

-- ----- Enums (존재 시 스킵) -----
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='room_listing_status') THEN
    CREATE TYPE room_listing_status AS ENUM ('listed','paused','rented','hidden');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='room_listing_kind') THEN
    CREATE TYPE room_listing_kind AS ENUM ('offer','wanted'); -- 방 내놓음 / 방 구함
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='occupancy_type') THEN
    CREATE TYPE occupancy_type AS ENUM ('entire','private_room','shared_room');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='lease_type') THEN
    CREATE TYPE lease_type AS ENUM ('short_term','long_term','flexible');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='furnishing') THEN
    CREATE TYPE furnishing AS ENUM ('unfurnished','semi_furnished','furnished');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='bill_policy') THEN
    CREATE TYPE bill_policy AS ENUM ('included','partial','excluded');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='gender_pref') THEN
    CREATE TYPE gender_pref AS ENUM ('any','male_only','female_only');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='smoking_policy') THEN
    CREATE TYPE smoking_policy AS ENUM ('allowed','not_allowed','outside_only');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='billing_cycle') THEN
    CREATE TYPE billing_cycle AS ENUM ('monthly','weekly','daily');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='room_interest_status') THEN
    CREATE TYPE room_interest_status AS ENUM ('open','contacted','accepted','rejected','withdrawn');
  END IF;
END$$;

-- ----- 메인: 하우징 리스트 -----
CREATE TABLE IF NOT EXISTS room_listing (
  id                BIGSERIAL PRIMARY KEY,
  lister_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- 등록자
  kind              room_listing_kind NOT NULL DEFAULT 'offer',              -- offer/wanted
  status            room_listing_status NOT NULL DEFAULT 'listed',

  -- 연결(옵션): 게시글과 연동하고 싶을 때
  post_id           BIGINT REFERENCES post(id) ON DELETE SET NULL,

  title             VARCHAR(200) NOT NULL,
  description_md    TEXT,
  currency          CHAR(3)  NOT NULL DEFAULT 'KRW',
  rent_amount       NUMERIC(12,2) NOT NULL,                                  -- 임대료
  billing           billing_cycle NOT NULL DEFAULT 'monthly',                -- 월/주/일 단위
  deposit_amount    NUMERIC(12,2),                                           -- 보증금
  bills_policy      bill_policy NOT NULL DEFAULT 'partial',                  -- 공과금 포함 여부
  bills_estimate    NUMERIC(12,2),                                           -- 공과금 예상치(옵션)

  lease             lease_type NOT NULL DEFAULT 'flexible',
  occupancy         occupancy_type NOT NULL DEFAULT 'private_room',
  property_type     VARCHAR(32) DEFAULT 'apartment',                         -- 자유 입력도 허용
  furnishing_level  furnishing NOT NULL DEFAULT 'semi_furnished',
  gender_preference gender_pref NOT NULL DEFAULT 'any',
  pet_policy        VARCHAR(24) DEFAULT 'negotiable',
  smoking           smoking_policy NOT NULL DEFAULT 'outside_only',

  available_from    TIMESTAMPTZ,
  available_to      TIMESTAMPTZ,
  min_term_months   INT,
  max_term_months   INT,

  occupants_current INT,
  occupants_max     INT,
  room_size_m2      NUMERIC(6,2),
  floor             INT,
  has_elevator      BOOLEAN,
  parking_available BOOLEAN,

  -- 위치
  country_code      VARCHAR(2) REFERENCES geo_country(code) ON DELETE SET NULL,
  city              VARCHAR(100),
  district          VARCHAR(100),
  address_text      TEXT,                                                    -- 상세주소(비공개 처리 권장)
  lat               DOUBLE PRECISION,
  lon               DOUBLE PRECISION,

  -- 조회/필터 확장
  amenities         JSONB NOT NULL DEFAULT '{}'::jsonb,                      -- 예: {"wifi":true,"ac":true,"desk":true}
  contact_pref      TEXT,                                                    -- 연락 선호(카톡/이메일 등 텍스트)

  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_room_listing_lister    ON room_listing(lister_id);
CREATE INDEX IF NOT EXISTS idx_room_listing_status    ON room_listing(status);
CREATE INDEX IF NOT EXISTS idx_room_listing_geo       ON room_listing(country_code, city, district);
CREATE INDEX IF NOT EXISTS idx_room_listing_amount    ON room_listing(rent_amount);
CREATE INDEX IF NOT EXISTS idx_room_listing_amenities ON room_listing USING GIN (amenities);
CREATE TRIGGER trg_room_listing_updated
BEFORE UPDATE ON room_listing
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ----- 이미지 -----
CREATE TABLE IF NOT EXISTS room_image (
  id         BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL REFERENCES room_listing(id) ON DELETE CASCADE,
  storage_key TEXT NOT NULL,
  is_cover   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_room_image_listing ON room_image(listing_id);

-- ----- 즐겨찾기 -----
CREATE TABLE IF NOT EXISTS room_favorite (
  listing_id BIGINT NOT NULL REFERENCES room_listing(id) ON DELETE CASCADE,
  user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (listing_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_room_fav_user ON room_favorite(user_id);

-- ----- 문의/관심(매칭 시작점) -----
CREATE TABLE IF NOT EXISTS room_interest (
  id          BIGSERIAL PRIMARY KEY,
  listing_id  BIGINT NOT NULL REFERENCES room_listing(id) ON DELETE CASCADE,
  user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,   -- 문의자
  message     TEXT,
  status      room_interest_status NOT NULL DEFAULT 'open',
  dm_thread_id BIGINT REFERENCES dm_thread(id) ON DELETE SET NULL,      -- DM 연결 시
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (listing_id, user_id)                                          -- 중복 문의 방지(1:1)
);
CREATE INDEX IF NOT EXISTS idx_room_interest_listing ON room_interest(listing_id);
CREATE INDEX IF NOT EXISTS idx_room_interest_user    ON room_interest(user_id);
CREATE TRIGGER trg_room_interest_updated
BEFORE UPDATE ON room_interest
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ----- 뷰: 활성(노출 가능) 매물 -----
CREATE OR REPLACE VIEW v_room_listing_active AS
SELECT rl.*
FROM room_listing rl
WHERE rl.status IN ('listed','paused')   -- paused는 검색 노출 O/예약만 제한 등 정책에 맞게 조정
  AND (rl.available_to IS NULL OR rl.available_to >= now());

-- ----- 샘플 인덱스/가이드 -----
-- 가격대 필터 + 지역 검색이 많다면 조합 인덱스 고려:
-- CREATE INDEX IF NOT EXISTS idx_room_geo_price ON room_listing(country_code, city, rent_amount);
