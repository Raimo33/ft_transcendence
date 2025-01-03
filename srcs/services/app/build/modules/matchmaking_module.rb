# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    matchmaking_module.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/03 12:07:04 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 19:25:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'
require_relative '../shared/config_handler'
require_relative '../shared/pg_client'
require_relative '../shared/memcached_client'
require_relative '../shared/exceptions'

class MatchmakingModule
  include Singleton
  
  def initialize
    @config = ConfigHandler.instance.config.fetch(:matchmaking)
    @pg_client = PGClient.instance
    @memcached_client = MemcachedClient.instance

    @pg_client.prepare_statements(PREPARED_STATEMENTS)
  end

  def add_matchmaking_user(user_id)
    @pg_client.exec_prepared('add_matchmaking_user', [user_id])
  end
  
  def remove_matchmaking_user(user_id)  
    @pg_client.exec_prepared('remove_matchmaking_user', [user_id])
  end

  def add_match_invitation(from_user_id, to_user_id)
    user_ids = [from_user_id, to_user_id].sort
    result = @memcached_client.add(":match_invitation#{user_ids[0]}:#{user_ids[1]}")
    raise Conflict.new("Match invitation already exists") unless result
  end

  def remove_match_invitation(fromm_user_id, to_user_id)
    user_ids = [from_user_id, to_user_id].sort
    success = @memcached_client.delete(":match_invitation#{user_ids[0]}:#{user_ids[1]}")
    raise NotFound.new("Match invitation not found") unless success
  end

  private

  PREPARED_STATEMENTS = {
    add_matchmaking_user: <<~SQL
      INSERT INTO MatchmakingPool (user_id)
      VALUES ($1)
    SQL
    remove_matchmaking_user: <<~SQL
      DELETE FROM MatchmakingPool
      WHERE user_id = $1
    SQL
  }.freeze

end