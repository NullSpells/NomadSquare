SET TIME ZONE 'Asia/Seoul';
-- ALTER DATABASE NomadSquare_db SET timezone TO 'Asia/Seoul';

CREATE TABLE IF NOT EXISTS message (
    id SERIAL PRIMARY KEY,
    text VARCHAR(255) NOT NULL
);

INSERT INTO message (text) VALUES ('Hello from PostgreSQL!');

commit;