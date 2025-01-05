
CREATE FUNCTION refresh_userfriendschronologicalmatview()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW UserFriendsChronologicalMatView;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_refresh_userfriendschronologicalmatview_userfriends
AFTER INSERT OR DELETE ON UserMatches
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_userfriendschronologicalmatview();


CREATE FUNCTION refresh_usermatchchronologicalmatview()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW UserMatchChronologicalMatView;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_refresh_usermatchchronologicalmatview_usermatches
AFTER INSERT OR DELETE ON UserMatches
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_usermatchchronologicalmatview();


CREATE OR REPLACE FUNCTION refresh_matchesinfomatview()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW MatchesInfoMatView;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_refresh_matchesinfomatview_matches
AFTER INSERT OR UPDATE OR DELETE ON Matches
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_matchesinfomatview();

CREATE TRIGGER trigger_refresh_matchesinfomatview_matchplayers
AFTER INSERT OR UPDATE OR DELETE ON MatchPlayers
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_matchesinfomatview();