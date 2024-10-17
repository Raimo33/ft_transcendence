CREATE DATABASE pongfumasters WITH
OWNER = beetle
ENCODING = 'UTF8'
LC_COLLATE = 'en_US.UTF-8'
LC_CTYPE = 'en_US.UTF-8'
TEMPLATE = template0
CONNECTION LIMIT = -1;

\c $DB_NAME;

CREATE TYPE user_status AS ENUM ('O', 'F'); -- O: online, F: offline

CREATE  TABLE User
(
    id                   uuid  NOT NULL,
    email                text  NOT NULL,
    psw                  text  NOT NULL,
    display_name         varchar(25) NOT NULL,
    avatar               bytea,
    two_factor_auth      boolean DEFAULT false NOT NULL,
    current_status       user_status DEFAULT 'F' NOT NULL,
    registered_timestamp timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_active          timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,

    CONSTRAINT pk_usr PRIMARY KEY (id),
    CONSTRAINT unq_usr_email UNIQUE (email) DEFERRABLE INITIALLY DEFERRED,

    CONSTRAINT chk_email CHECK (email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'),
    CONSTRAINT chk_avatar CHECK (LENGTH(avatar) <= 5242880),
    CONSTRAINT chk_last_active CHECK (last_active <= NOW()),
    CONSTRAINT chk_registered_timestamp CHECK (registered_timestamp <= NOW())
);

CREATE INDEX idx_usr_display_name ON usr USING btree (display_name);
CREATE INDEX idx_usr_registered_timestamp ON usr USING btree (registered_timestamp);
CREATE INDEX idx_usr_last_active ON usr USING btree (last_active);

CREATE TYPE match_status AS ENUM ('O', 'C', 'I'); -- O: ongoing, C: completed, I: interrupted

CREATE  TABLE GameMatch
(
    id                   uuid NOT NULL,
    current_status       match_status DEFAULT 'O' NOT NULL,
    websocket_url        text,
    ball_speed           smallint DEFAULT 50 NOT NULL,
    max_duration         smallint DEFAULT 600 NOT NULL,
    starting_health      smallint DEFAULT 3 NOT NULL,
    started_timestamp    timestamptz DEFAULT CURRENT_TIMESTAMP,
    finished_timestamp   timestamptz DEFAULT CURRENT_TIMESTAMP,
    tournament_id        uuid,
    leaderboard          uuid[] DEFAULT '{}' NOT NULL,

    CONSTRAINT           pk_game_match PRIMARY KEY (id),
    CONSTRAINT           unq_game_match_tournament_id UNIQUE (tournament_id) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT           unq_game_match_websocket_url UNIQUE (websocket_url) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT           fk_game_match_game_tournament FOREIGN KEY (tournament_id) REFERENCES game_tournament(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,

    CONSTRAINT           chk_websocket_url CHECK (websocket_url ~ '^wss?://([\\w-]+\\.)+[\\w-]+(:\\d+)?(/[\\w-./?%&=]*)?$'),
    CONSTRAINT           chk_ball_speed CHECK (ball_speed <= 100 AND ball_speed > 0),
    CONSTRAINT           chk_starting_health CHECK (starting_health >= 1 AND starting_health <= 100),
    CONSTRAINT           chk_started_timestamp CHECK (started_timestamp <= NOW()),
    CONSTRAINT           chk_finished_timestamp CHECK (finished_timestamp <= NOW()),
);


CREATE INDEX idx_game_match_started_timestamp ON game_match USING btree (started_timestamp);
CREATE INDEX idx_game_match_finished_timestamp ON game_match USING btree (finished_timestamp);
CREATE INDEX idx_game_match_outcome_started_timestamp ON game_match USING btree (outcome, started_timestamp);
CREATE INDEX idx_game_match_outcome_finished_timestamp ON game_match USING btree (outcome, finished_timestamp);


CREATE TYPE tournament_play_mode AS ENUM ('single-elimination', 'knockout', 'king_of_the_hill', 'ladder', 'round_robin');
CREATE TYPE tournament_status AS ENUM ('O', 'C', 'I'); -- O: ongoing, C: completed, I: interrupted

CREATE  TABLE GameTournament
(
    id                   uuid  NOT NULL,
    play_mode            tournament_play_mode DEFAULT 'single-elimination' NOT NULL,
    current_status       tournament_status DEFAULT 'O' NOT NULL,
    started_timestamp    timestamptz DEFAULT CURRENT_TIMESTAMP,
    finished_timestamp   timestamptz DEFAULT CURRENT_TIMESTAMP,
    leaderboard          uuid[] DEFAULT '{}' NOT NULL,

    CONSTRAINT           pk_game_tournament PRIMARY KEY (id),
    CONSTRAINT

    CONSTRAINT           chk_started_timestamp CHECK (started_timestamp <= NOW()),
    CONSTRAINT           chk_finished_timestamp CHECK (finished_timestamp <= NOW())
);

CREATE INDEX idx_game_tournament_started_timestamp ON game_tournament (started_timestamp);
CREATE INDEX idx_game_tournament_finished_timestamp ON game_tournament (finished_timestamp);
CREATE INDEX idx_game_tournament_mode_started_timestamp ON game_tournament (play_mode, started_timestamp);
CREATE INDEX idx_game_tournament_mode_finished_timestamp ON game_tournament (play_mode, finished_timestamp);

CREATE  TABLE UserMatches
(
    user_id              uuid  NOT NULL,
    match_id             uuid  NOT NULL,

    CONSTRAINT           pk_usermatches PRIMARY KEY (match_id, user_id),
    CONSTRAINT           fk_usermatches_match_id FOREIGN KEY (match_id) REFERENCES game_match(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT           fk_usermatches_user_id FOREIGN KEY (user_id) REFERENCES usr(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE  TABLE UserTournaments
(
    user_id              uuid  NOT NULL,
    tournament_id        uuid  NOT NULL,

    CONSTRAINT           pk_usertournaments PRIMARY KEY (tournament_id, user_id),
    CONSTRAINT           fk_usertournaments_tournament_id FOREIGN KEY (tournament_id) REFERENCES game_tournament(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT           fk_usertournaments_user_id FOREIGN KEY (user_id) REFERENCES usr(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE MATERIALIZED VIEW user_activity_summary AS
SELECT
    u.id AS user_id,
    u.display_name,
    COUNT(um.match_id) AS total_matches,
    COUNT(ut.tournament_id) AS total_tournaments,
    u.last_active AS last_active
FROM
    usr u
LEFT JOIN
    usermatches um ON u.id = um.user_id
LEFT JOIN
    usertournaments ut ON u.id = ut.user_id
GROUP BY
    u.id, u.display_name;

CREATE MATERIALIZED VIEW match_summary AS
SELECT
    gm.id AS match_id,
    gm.current_status,
    gm.ball_speed,
    gm.starting_health,
    gm.started_timestamp,
    gm.finished_timestamp,
    COUNT(um.user_id) AS total_players,
    EXTRACT(EPOCH FROM (gm.finished_timestamp - gm.started_timestamp)) AS duration
FROM
    gamematch gm
LEFT JOIN
    usermatches um ON gm.id = um.match_id
GROUP BY
    gm.id, gm.current_status, gm.ball_speed, gm.starting_health, gm.started_timestamp, gm.finished_timestamp;

CREATE MATERIALIZED VIEW tournament_summary AS
SELECT
    gt.id AS tournament_id,
    gt.play_mode,
    gt.current_status,
    gt.started_timestamp,
    gt.finished_timestamp,
    COUNT(ut.user_id) AS total_players,
    EXTRACT(EPOCH FROM (gt.finished_timestamp - gt.started_timestamp)) AS duration
FROM
    gametournament gt
LEFT JOIN
    usertournaments ut ON gt.id = ut.tournament_id
GROUP BY
    gt.id, gt.play_mode, gt.current_status, gt.started_timestamp, gt.finished_timestamp;
