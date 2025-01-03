# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_module.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/03 12:07:04 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 19:34:39 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'
require_relative '../shared/config_handler'
require_relative '../shared/pg_client'
require_relative '../shared/exceptions'

class MatchModule
  include Singleton
  
  def initialize
    @config = ConfigHandler.instance.config.fetch(:match)
    @pg_client = PGClient.instance

    @pg_client.prepare_statements(PREPARED_STATEMENTS)
  end

  private

  PREPARED_STATEMENTS = {
    get_user_matches: <<~SQL
      SELECT match_id
      FROM MatchPlayersChronologicalMatView
      WHERE user_id = $1 AND (started_at, match_id) < ($2, $3)
      LIMIT $4
    SQL
    is_playing: <<~SQL
      SELECT EXISTS (
        SELECT 1
        FROM MatchPlayers
        WHERE user_id = $1 AND ended_at IS NULL
      ) AS is_playing
    SQL
    are_friends: <<~SQL
      SELECT EXISTS (
        SELECT 1
        FROM Friendships
        WHERE user_id_1 = $1 AND user_id_2 = $2
      ) AS are_friends
    SQL
    get_user_status: <<~SQL
      SELECT current_status
      FROM Users
      WHERE user_id = $1
    SQL
    get_match_info: <<~SQL
      SELECT *
      FROM MatchesInfoMatView
      WHERE id = $1
    SQL
    insert_match: <<~SQL
      INSERT INTO Matches (id)
      VALUES ($1)
      RETURNING id
    SQL
    insert_match_players: <<~SQL
      INSERT INTO MatchPlayers
      VALUES ($1, $2), ($1, $3)
    SQL
    delete_match: <<~SQL
      DELETE FROM Matches
      WHERE id = $1
    SQL
    update_match: <<~SQL
      UPDATE Matches
      SET status = $2, ended_at = $3
      WHERE id = $1
    SQL
    set_winner: <<~SQL
      UPDATE MatchPlayers
      SET position = CASE
        WHEN user_id = $2 THEN 1
        ELSE 2
      END
      WHERE match_id = $1
    SQL
  }.freeze

end