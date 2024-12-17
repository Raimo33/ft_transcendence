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

CREATE MATERIALIZED VIEW MatchPlayersChronologicalMatView AS
SELECT
  um.user_id,
  um.match_id,
  m.started_at
  m.ended_at
FROM
  MatchPlayers um
JOIN
  Matches m ON um.match_id = m.id
ORDER BY
  um.user_id,
  m.started_at DESC,
  um.match_id DESC;

CREATE INDEX idx_usermatchechronologicalmatview_userid                  ON MatchPlayersChronologicalMatView USING HASH (user_id);
CREATE INDEX idx_usermatchchronologicalmatview_userid_createdat_matchid ON MatchPlayersChronologicalMatView (started_at DESC, match_id DESC);

CREATE MATERIALIZED VIEW MatchesInfoMatView AS
SELECT
  m.id,
  m.current_status,
  m.started_at,
  m.ended_at,
  m.tournament_id,
  array_agg(mp.user_id) AS player_ids
FROM Matches m
JOIN MatchPlayers mp ON m.id = mp.match_id
GROUP BY m.id;

CREATE INDEX idx_matchesinfomatview_id ON MatchesInfoMatView USING HASH (id);
