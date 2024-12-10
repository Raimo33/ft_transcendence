CREATE DATABASE pongfumasters WITH OWNER = postgresql;

\c pongfumasters

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TYPE user_status AS ENUM ('online', 'offline', 'banned');

CREATE TABLE Users
(
  id                       uuid  NOT NULL DEFAULT gen_random_uuid(),
  email                    text  NOT NULL,
  psw                      text  NOT NULL,
  tfa_secret               text,
  display_name             varchar(25) NOT NULL,
  avatar                   bytea,
  tfa_status               boolean DEFAULT false NOT NULL,
  current_status           user_status DEFAULT 'offline' NOT NULL,

  CONSTRAINT pk_users               PRIMARY KEY (id),
  CONSTRAINT unq_users_email        UNIQUE (email),
  CONSTRAINT unq_users_displayname  UNIQUE (display_name),

  CONSTRAINT chk_users_email        CHECK (email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT chk_users_displayname  CHECK (LENGTH(display_name) <= 25 AND LENGTH(display_name) > 3 AND display_name ~ '^[a-zA-Z0-9_]+$'),
  CONSTRAINT chk_users_avatar       CHECK (LENGTH(avatar) <= 5242880)
);

CREATE TYPE match_status AS ENUM ('ongoing', 'completed');

CREATE TABLE Matches
(
  id                uuid NOT NULL,
  creator_id        uuid NOT NULL,
  current_status    match_status DEFAULT 'ongoing' NOT NULL,
  started_at        timestamptz DEFAULT CURRENT_TIMESTAMP,
  finished_at       timestamptz DEFAULT CURRENT_TIMESTAMP,
  tournament_id     uuid,

  CONSTRAINT    pk_matches                PRIMARY KEY (id),
  CONSTRAINT    fk_matches_creatorid      FOREIGN KEY (creator_id)    REFERENCES Users(id)       ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT    fk_matches_tournament     FOREIGN KEY (tournament_id) REFERENCES Tournaments(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT    unq_matches_tournamentid  UNIQUE (tournament_id) DEFERRABLE INITIALLY DEFERRED,

  CONSTRAINT    chk_matches_startedat   CHECK (started_at <= NOW()),
  CONSTRAINT    chk_matches_finishedat  CHECK (finished_at <= NOW())
) PARTITION BY RANGE (started_at);

CREATE INDEX idx_match_startedat  ON Matches(started_at DESC);
CREATE INDEX idx_match_finishedat ON Matches(finished_at);

CREATE TYPE tournament_status AS ENUM ('pending', 'ongoing', 'completed', 'cancelled');

CREATE TABLE Tournaments
(
  id               uuid  NOT NULL,
  creator_id       uuid  NOT NULL,
  current_status   tournament_status DEFAULT 'pending' NOT NULL,
  started_at       timestamptz DEFAULT CURRENT_TIMESTAMP,
  finished_at      timestamptz DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT  pk_tournaments          PRIMARY KEY (id),
  CONSTRAINT  fk_tournaments_creator  FOREIGN KEY (creator_id) REFERENCES Users(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  
  CONSTRAINT  chk_tournaments_startedat   CHECK (started_at  <= NOW()),
  CONSTRAINT  chk_tournaments_finishedat  CHECK (finished_at <= NOW())
) PARTITION BY RANGE (started_at);

CREATE INDEX idx_tournament_startedat   ON Tournaments(started_at DESC);
CREATE INDEX idx_tournament_finishedat  ON Tournaments(finished_at);

CREATE TYPE friendship_status AS ENUM ('pending', 'accepted', 'blocked', 'rejected');

CREATE TABLE Friendships
(
  user_id_1       uuid NOT NULL,
  user_id_2       uuid NOT NULL,
  current_status  friendship_status DEFAULT 'pending' NOT NULL,

  CONSTRAINT pk_friendships       PRIMARY KEY (user_id_1, user_id_2),
  CONSTRAINT fk_friendships_user1 FOREIGN KEY (user_id_1) REFERENCES Users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_friendships_user2 FOREIGN KEY (user_id_2) REFERENCES Users(id) ON DELETE CASCADE ON UPDATE CASCADE,

  CONSTRAINT chk_friendships_different_users CHECK (user_id_1 < user_id_2)
) PARTITION BY HASH (user_id_1);

CREATE INDEX idx_friendships_user1_status ON Friendships(user_id_1, current_status);
CREATE INDEX idx_friendships_user2_status ON Friendships(user_id_2, current_status);

CREATE TABLE UserMatches
(
  user_id   uuid  NOT NULL,
  match_id  uuid  NOT NULL,
  position  smallint NOT NULL,

  CONSTRAINT   pk_usermatches          PRIMARY KEY (match_id, user_id),
  CONSTRAINT   fk_usermatches_matchid  FOREIGN KEY (match_id) REFERENCES Matches(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT   fk_usermatches_userid   FOREIGN KEY (user_id)  REFERENCES Users(id)   ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
) PARTITION BY HASH (user_id);

CREATE INDEX idx_usermatches_userid           ON UserMatches(user_id);
CREATE INDEX idx_usermatches_matchid_position ON UserMatches(match_id, position);

CREATE TABLE UserTournaments
(
  user_id        uuid  NOT NULL,
  tournament_id  uuid  NOT NULL,
  position       smallint NOT NULL,

  CONSTRAINT  pk_usertournaments               PRIMARY KEY (tournament_id, user_id),
  CONSTRAINT  fk_usertournaments_tournamentid  FOREIGN KEY (tournament_id) REFERENCES Tournaments(id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT  fk_usertournaments_userid        FOREIGN KEY (user_id)       REFERENCES Users(id)       ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
) PARTITION BY HASH (user_id);

CREATE INDEX idx_usertournaments_userid                ON UserTournaments(user_id);
CREATE INDEX idx_usertournaments_tournamentid_position ON UserTournaments(tournament_id, position);

CREATE VIEW UserPublicProfiles AS
SELECT 
  id,
  display_name,
  avatar,
  current_status
FROM 
  Users;

CREATE VIEW UserPrivateProfiles AS
SELECT 
  id,
  email,
  display_name,
  avatar,
  tfa_status,
  current_status
FROM
  Users;

--TODO capire quando e' meglio fare il refresh della view (se viene fatto ad ogni inserimento succede che le queries si possono perdere determinati valori o ripetere piu valori siccome i match possono solo aumentare)
CREATE MATERIALIZED VIEW UserMatchSorted AS
SELECT 
  um.user_id,
  um.match_id,
  m.created_at,
  ROW_NUMBER() OVER (PARTITION BY um.user_id ORDER BY m.created_at DESC) AS age
FROM
  UserMatches um
JOIN
  Matches m ON um.match_id = m.id;

-- TODO hashed index di 'created_at' + keyset pagination? cosi' la chiave fornita viene paragonata all'index in O(1)