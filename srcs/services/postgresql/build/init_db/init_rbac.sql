CREATE USER app WITH PASSWORD 'password';
CREATE USER match_state WITH PASSWORD 'password'

GRANT SELECT INSERT UPDATE DELETE ON ALL TABLES IN SCHEMA public TO app;

GRANT SELECT INSERT UPDATE DELETE ON Matches      TO match_state;
GRANT SELECT INSERT UPDATE DELETE ON Tournaments  TO match_state;