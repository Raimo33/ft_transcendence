# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_handler_module.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/05 00:04:43 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 01:03:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'
require 'eventmachine'
require_relative 'connection_module'
require_relative '../match'
require_relative '../shared/pg_client'
require_relative '../shared/config_handler'

class MatchHandlerModule
  include Singleton

  def initialize
    @pg_client = PGClient.instance
    @config = ConfigHandler.instance.config

    @connection_module = ConnectionModule.instance

    @matches = Hash.new { |hash, key| hash[key] = Match.new(key) }
    @pg_client.prepare_statements(PREPARED_STATEMENTS)
  end

  def stop_all
    @matches.each_value(&:stop) #TODO aggiungere e implementare il metodo stop con chiusura websocket
  end

  def add_match(match_id, user_id1, user_id2)
    return false if @matches.key?(match_id)
    match = Match.new(user_id1, user_id2)
    @matches[match_id] = match

    EM.add_timer(@config.dig(:match, :grace_period)) do
      return false unless @matches.key?(match_id)
      loser_id = match.player_connected?(user_id1) ? user_id2 : user_id1
      match.surrender_player(loser_id)
    end
  end

  def remove_match(match_id)
    return false unless @matches.key?(match_id)
    @matches[match_id].stop
    @matches.delete(match_id)
  end

  def update_game_states
    @matches.each_value(&:update)
  end

  def add_player(match_id, user_id, ws)
    match = @matches.fetch(match_id, nil)
    raise NotFound.new("Match not found") unless match
    match.add_player(user_id, ws)
  end

  def remove_player(match_id, user_id)
    match = @matches.fetch(match_id, nil)
    return unless match

    grace_period = @config.dig(:match, :grace_period)
    match.pause_player(user_id)
    EM.add_timer(grace_period) do
      match.surrender_player(user_id) if (match.state[:status] == :waiting)
    end
  end

  def add_input(match_id, data)
    match = @matches.fetch(match_id, nil)
    if (match.ongoing?)
      @matches[match_id].queue_input(data)
    else
      @connection_module.send_error(ws, 400, "Match not ongoing")
    end
  end

  private

  PREPARED_STATEMENTS = {
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