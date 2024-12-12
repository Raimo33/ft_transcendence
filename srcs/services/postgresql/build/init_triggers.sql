\c pongfumasters

CREATE FUNCTION refresh_usermatchchronologicalmatview()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW UserMatchChronologicalMatView;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER refresh_usermatchchronologicalmatview
AFTER INSERT OR DELETE ON UserMatches
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_usermatchchronologicalmatview();

