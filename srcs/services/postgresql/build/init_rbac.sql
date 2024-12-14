\c pongfumasters

CREATE USER user        WITH PASSWORD 'password';
CREATE USER match       WITH PASSWORD 'password';
CREATE USER tournament  WITH PASSWORD 'password';

GRANT SELECT, INSERT, UPDATE  ON Users               TO user;
GRANT SELECT                  ON UserPublicProfiles  TO user;
GRANT SELECT, UPDATE          ON UserPrivateProfiles TO user;

GRANT SELECT, INSERT, UPDATE ON Matches     TO match;
GRANT SELECT, INSERT, UPDATE ON UserMatches TO match;

GRANT SELECT, INSERT, UPDATE ON Tournaments     TO tournament;
GRANT SELECT, INSERT, UPDATE ON UserTournaments TO tournament;