# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match.rb                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/27 15:26:33 by craimond          #+#    #+#              #
#    Updated: 2024/12/31 17:40:50 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'config_handler'

class Match
  attr_reader :players, :state

  @config = ConfigHandler.instance.config

  def initialize(id)
    @id = id
    @players = {}
    @paused_players = {}
    @state = {
      ball_position: { x: 0, y: 0 },
      ball_velocity: { x: 0, y: 0 },
      paddle_positions: {
        player_1: 0.5,
        player_2: 0.5,
      },
      health_points: {
        player_1: @config['settings']['initial_hp'],
        player_2: @config['settings']['initial_hp'],
      },
      status: :waiting,
      timestamp: Time.now.to_i,
    }
    @input_queue = []
  end

  def add_player(user_id, ws)
    @players[user_id] = ws
    @paused_players.delete(user_id)
    if @players.size == 2 && @state[:status] == :waiting
      @state[:status] = :ongoing
      send_initial_state
    end
  end

  def pause_player(user_id)
    @paused_players[user_id] = @players[user_id]
    @state[:status] = :waiting
  end

  def surrender_player(user_id)
    player_role = user_id == @players[0] ? :player_1 : :player_2
    @status[:health_points][player_role] = 0
    @state[:status] = :over
  end

  def ongoing?
    @players.size > 1
  end    

  def queue_input(input)
    @input_queue << input
  end

  def update
    return unless @status == :ongoing
    
    process_inputs
    state[:timestamp] = Time.now.to_i
  end
  
  private

  def send_initial_state
    payload = {
      operation_id: 'players_info',
      player_1_id: @players.keys[0],
      player_2_id: @players.keys[1],
    }
    payload = JSON.generate(initial_state)
    @players.each do |user_id, ws|
      ws.send(payload)
    end
  end
  
  def process_inputs
    @input_queue.each do |input|
      apply_input(input)
    end
    @input_queue.clear
  end

  def apply_input(input)
    direction = input['direction']
    timestamp = input['timestamp']
    #how can i handle lag compensation? the client sends me a timestamp along with each input. how is lag compensation usually handled in online multiplayer games?
    #TODO update game state, check for collisions, check for game over etc
    #TODO raise exception if input is invalid
  end

end