CREATE OR REPLACE FUNCTION order_friendship_ids()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id_1 > NEW.user_id_2 THEN
    RETURN ROW(NEW.user_id_2, NEW.user_id_1);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_order_friendship_ids
BEFORE INSERT OR UPDATE ON Friendships
FOR EACH ROW
EXECUTE FUNCTION order_friendship_ids();


CREATE FUNCTION refresh_usermatchchronologicalmatview()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW UserMatchChronologicalMatView;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_refresh_usermatchchronologicalmatview
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

CREATE TRIGGER trigger_refresh_matchesinfomatview
AFTER INSERT OR UPDATE OR DELETE ON Matches
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_matchesinfomatview();

CREATE TRIGGER trigger_refresh_matchesinfomatview
AFTER INSERT OR UPDATE OR DELETE ON MatchPlayers
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_matchesinfomatview();