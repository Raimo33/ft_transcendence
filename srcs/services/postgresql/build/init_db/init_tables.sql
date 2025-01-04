CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_status AS ENUM ('online', 'offline', 'banned');

CREATE TABLE Users
(
  id               uuid NOT NULL DEFAULT gen_random_uuid(),
  email            text NOT NULL,
  psw              text NOT NULL,
  tfa_secret       text,
  display_name     varchar(25) NOT NULL,
  avatar           bytea,
  tfa_status       boolean NOT NULL DEFAULT false,
  current_status   user_status NOT NULL DEFAULT 'offline',
  created_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT pk_users               PRIMARY KEY (id),
  CONSTRAINT unq_users_email        UNIQUE (email),
  CONSTRAINT unq_users_displayname  UNIQUE (display_name),

  CONSTRAINT chk_users_email        CHECK (email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT chk_users_displayname  CHECK (LENGTH(display_name) <= 25 AND LENGTH(display_name) > 3 AND display_name ~ '^[a-zA-Z0-9_]+$'),
  CONSTRAINT chk_users_avatar       CHECK (LENGTH(avatar) <= 5242880)
);

CREATE INDEX idx_users_id          ON Users(id)           USING HASH;
CREATE INDEX idx_users_displayname ON Users(display_name) USING HASH;

CREATE TYPE match_status AS ENUM ('pending', 'ongoing', 'ended');

CREATE TABLE Matches
(
  id              uuid NOT NULL gen_random_uuid(),
  current_status  match_status  NOT NULL DEFAULT 'ongoing',
  started_at      timestamptz   NOT NULL DEFAULT now(),
  ended_at        timestamptz,
  tournament_id   uuid,

  CONSTRAINT  pk_matches                PRIMARY KEY (id),
  CONSTRAINT  fk_matches_tournamentid   FOREIGN KEY (tournament_id) REFERENCES Tournaments(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT  unq_matches_tournamentid  UNIQUE (tournament_id) DEFERRABLE INITIALLY DEFERRED,

  CONSTRAINT  chk_matches_startedat   CHECK (started_at <= NOW()),
  CONSTRAINT  chk_matches_endedat     CHECK (ended_at <= NOW())
);

CREATE INDEX idx_matches_id         ON Matches(id) USING HASH;
CREATE INDEX idx_matches_startedat  ON Matches(started_at DESC);
CREATE INDEX idx_matches_endedat ON Matches(ended_at);

CREATE TYPE tournament_status AS ENUM ('pending', 'ongoing', 'ended', 'cancelled');

CREATE TABLE Tournaments
(
  id              uuid NOT NULL gen_random_uuid(),
  creator_id      uuid NOT NULL,
  current_status  tournament_status NOT NULL DEFAULT 'pending',
  started_at      timestamptz NOT NULL DEFAULT now(),
  ended_at        timestamptz,

  CONSTRAINT  pk_tournaments            PRIMARY KEY (id),
  CONSTRAINT  fk_tournaments_creatorid  FOREIGN KEY (creator_id) REFERENCES Users(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  
  CONSTRAINT  chk_tournaments_startedat   CHECK (started_at  <= NOW()),
  CONSTRAINT  chk_tournaments_endedat  CHECK (ended_at <= NOW())
);

CREATE INDEX idx_tournaments_id         ON Tournaments(id) USING HASH;
CREATE INDEX idx_tournaments_startedat  ON Tournaments(started_at DESC);
CREATE INDEX idx_tournaments_endedat ON Tournaments(ended_at);

CREATE TYPE friendship_status AS ENUM ('pending', 'accepted', 'blocked');

CREATE TABLE Friendships
(
  user_id_1       uuid NOT NULL,
  user_id_2       uuid NOT NULL,
  current_status  friendship_status NOT NULL DEFAULT 'pending',
  created_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT pk_friendships       PRIMARY KEY (user_id_1, user_id_2),
  CONSTRAINT fk_friendships_userid1 FOREIGN KEY (user_id_1) REFERENCES Users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_friendships_userid2 FOREIGN KEY (user_id_2) REFERENCES Users(id) ON DELETE CASCADE ON UPDATE CASCADE,

  CONSTRAINT chk_friendships_different_users CHECK (user_id_1 < user_id_2)
);

CREATE INDEX idx_friendships_user1        ON Friendships(user_id_1) USING HASH;
CREATE INDEX idx_friendships_user1_status ON Friendships(user_id_1, current_status);
CREATE INDEX idx_friendships_user2_status ON Friendships(user_id_2, current_status);

CREATE TABLE MatchPlayers
(
  user_id   uuid NOT NULL,
  match_id  uuid NOT NULL,
  position  smallint,

  CONSTRAINT pk_matchplayers         PRIMARY KEY (match_id, user_id),
  CONSTRAINT fk_matchplayers_matchid FOREIGN KEY (match_id) REFERENCES Matches(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT fk_matchplayers_userid  FOREIGN KEY (user_id)  REFERENCES Users(id)   ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
)

CREATE INDEX idx_matchplayers_userid           ON MatchPlayers(user_id) USING HASH;
CREATE INDEX idx_matchplayers_matchid_position ON MatchPlayers(match_id, position);

CREATE TABLE TournamentPlayers
(
  user_id        uuid NOT NULL,
  tournament_id  uuid NOT NULL,
  position       smallint,

  CONSTRAINT  pk_tournamentplayers               PRIMARY KEY (tournament_id, user_id),
  CONSTRAINT  fk_tournamentplayers_tournamentid  FOREIGN KEY (tournament_id) REFERENCES Tournaments(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT  fk_tournamentplayers_userid        FOREIGN KEY (user_id)       REFERENCES Users(id)       ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
)

CREATE INDEX idx_tournamentplayers_userid                ON TournamentPlayers(user_id) USING HASH;
CREATE INDEX idx_tournamentplayers_tournamentid_position ON TournamentPlayers(tournament_id, position);

CREATE UNLOGGED TABLE MatchmakingPool
(
  user_id      uuid NOT NULL,
  added_at     timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT pk_matchmakingpool          PRIMARY KEY (user_id),
  CONSTRAINT fk_matchmakingpool_userid   FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
  CONSTRAINT chk_matchmakingpool_addedat CHECK (added_at <= NOW())
)

CREATE INDEX idx_matchmakingpool_addedat ON MatchmakingPool(added_at);