CREATE USER user        WITH PASSWORD 'password';
CREATE USER match       WITH PASSWORD 'password';
CREATE USER tournament  WITH PASSWORD 'password';
CREATE USER matchmaking WITH PASSWORD 'password';

GRANT SELECT, INSERT, UPDATE  ON Users               TO user;
GRANT SELECT                  ON UserPublicProfiles  TO user;
GRANT SELECT,                 ON UserPrivateProfiles TO user;
GRANT SELECT, INSERT, UPDATE  ON Friendships         TO user;

GRANT SELECT, INSERT, UPDATE ON Matches                          TO match;
GRANT SELECT,                ON UserPublicProfiles               TO match;
GRANT SELECT,                ON Friendships                      TO match;
GRANT SELECT, INSERT, UPDATE ON MatchPlayers                     TO match;
GRANT SELECT,                ON MatchPlayersChronologicalMatView TO match;
GRANT SELECT,                ON MatchesInfoMatView               TO match;

GRANT SELECT, INSERT, UPDATE ON Tournaments       TO tournament;
GRANT SELECT,                ON TournamentPlayers TO tournament;

GRANT SELECT, INSERT, UPDATE ON MatchmakingPool TO matchmaking;

GRANT 