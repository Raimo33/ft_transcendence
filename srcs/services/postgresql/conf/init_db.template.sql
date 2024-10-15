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

CREATE INDEX idx_usr_status ON usr USING btree (status);
CREATE INDEX idx_usr_display_name ON usr USING btree (display_name);
CREATE INDEX idx_usr_date_registered ON usr USING btree (date_registered);
CREATE INDEX idx_usr_last_active ON usr USING btree (last_active);
CREATE INDEX idx_usr_status_display_name ON usr USING btree (status, display_name);
CREATE INDEX idx_usr_status_last_active ON usr USING btree (status, last_active);
CREATE UNIQUE INDEX unq_idx_usr_status_email ON usr (status, email);


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
    duration             time,
    tournament_id        uuid,
    leaderboard          uuid[] DEFAULT '{}' NOT NULL,

    CONSTRAINT           pk_game_match PRIMARY KEY (id),
    CONSTRAINT           unq_game_match_tournament_id UNIQUE (tournament_id) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT           unq_game_match_websocket_url UNIQUE (websocket_url) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT           fk_game_match_game_tournament FOREIGN KEY (tournament_id) REFERENCES game_tournament(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,

    CONSTRAINT           chk_websocket_url CHECK (websocket_url ~ '^wss?://([\\w-]+\\.)+[\\w-]+(:\\d+)?(/[\\w-./?%&=]*)?$'),
    CONSTRAINT           chk_ball_speed CHECK (ball_speed <= 100 AND ball_speed > 0),
    CONSTRAINT           chk_max_duration CHECK (max_duration <= 3600 AND max_duration >= 60),
    CONSTRAINT           chk_starting_health CHECK (starting_health >= 1 AND starting_health <= 100),
    CONSTRAINT           chk_started_timestamp CHECK (started_timestamp <= NOW()),
    CONSTRAINT           chk_finished_timestamp CHECK (finished_timestamp <= NOW()),
);

CREATE OR REPLACE FUNCTION calculate_duration()
RETURNS TRIGGER AS $$
BEGIN
    NEW.duration := NEW.finished_timestamp - NEW.started_timestamp;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_duration
BEFORE INSERT OR UPDATE ON game_match
FOR EACH ROW
EXECUTE FUNCTION calculate_duration();

CREATE INDEX idx_game_match_outcome_started_timestamp ON game_match USING btree (outcome, started_timestamp);
CREATE INDEX idx_game_match_duration_outcome ON game_match USING btree (duration, outcome);


CREATE TYPE tournament_play_mode AS ENUM ('single-elimination', 'knockout', 'king_of_the_hill', 'ladder', 'round_robin');
CREATE TYPE tournament_status AS ENUM ('O', 'C', 'I'); -- O: ongoing, C: completed, I: interrupted

CREATE  TABLE GameTournament
(
    id                   uuid  NOT NULL,
    play_mode            tournament_play_mode DEFAULT 'single-elimination' NOT NULL,
    current_status       tournament_status DEFAULT 'O' NOT NULL,
    started_timestamp    timestamptz DEFAULT CURRENT_TIMESTAMP,
    finished_timestamp   timestamptz DEFAULT CURRENT_TIMESTAMP,
    duration             time,
    leaderboard          uuid[] DEFAULT '{}' NOT NULL,

    CONSTRAINT           pk_game_tournament PRIMARY KEY (id),

    CONSTRAINT           chk_started_timestamp CHECK (started_timestamp <= NOW()),
    CONSTRAINT           chk_finished_timestamp CHECK (finished_timestamp <= NOW())
);

CREATE TRIGGER trg_calculate_duration
BEFORE INSERT OR UPDATE ON game_tournament
FOR EACH ROW
EXECUTE FUNCTION calculate_duration();

CREATE INDEX idx_game_tournament_mode_started_timestamp ON game_tournament (play_mode, started_timestamp);


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