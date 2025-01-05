# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match.rb                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/27 15:26:33 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 16:10:15 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#TODO rinominare match into match

require_relative 'config_handler'
require_relative 'exceptions'

class Match
  attr_reader :players, :state

  @config = ConfigHandler.instance.config

  def self.max_hp
    @max_hp ||= @config.dig(:settings, :max_hp)
  end

  STARTING_match_state = {
    ball_position: Array.new(2, 0),
    ball_velocity: Array.new(2, 0),
    paddle_positions: Array.new(2, 0.5),
    health_points: Array.new(2, max_hp),
    status: :waiting,
    timestamp: 0,
  }

  def initialize(id, user_id1, user_id2)
    @id = id
    @allowed_players = [user_id1, user_id2].freeze
    @players = {}
    @state = deep_copy(STARTING_match_state)
    @input_queue = []
    @state_history = []
  end

  def add_player(user_id, ws)
    raise Unauthorized.new("User not allowed to join match") unless @allowed_players.include?(user_id)
    @players[user_id] = ws
    @players = @players.sort.to_h
    if @players.size == 2
      @state[:status] = :ongoing
    end
  end

  def pause_player(user_id)
    @players.delete(user_id)
    @state[:status] = :waiting
  end

  def surrender_player(user_id)
    idx = player_idx(user_id)
    @status[:health_points][idx] = 0
    @state[:status] = :ended
  end

  def player_connected?(user_id)
    @players.keys.include?(user_id)
  end

  def queue_input(input)
    @input_queue << input
  end

  #TODO refactor e ricontrollare in base a aas

  # def update
  #   return unless @status == :ongoing
    
  #   current_time = current_time_ms
  #   process_inputs(current_time)
    
  #   @state_history << deep_copy(@state)
  #   @state_history.reject! { |s| current_time - s[:timestamp] > @config.dig(:server, :max_lag_compensation) }
  
  #   @state[:timestamp] = current_time
  # end

  # private

  # def process_inputs
  #   @input_queue.sort_by! { |input| input[:timestamp] }
  #   @input_queue.each do |input|
  #     apply_input(input, current_time)
  #   end
  #   @input_queue.clear
  # end

  # def apply_input(input, current_time)
  #   user_id = input[:user_id]
  #   client_time = input[:timestamp]
  #   direction = input[:direction]
  #   check_required_fields(user_id, client_time, direction)
  #   raise GRPC::InvalidArgument.new('User not in match') unless @players.keys.include?(user_id)
  #   raise GRPC::InvalidArgument.new('Invalid direction format') unless [-1, 0, 1].include?(direction)
  #   raise GRPC::InvalidArgument.new('Invalid timestamp format') unless client_time.is_a?(Integer)

  #   server_delay = current_time - client_time
  #   return if server_delay > @config.dig(:server, :max_lag_compensation)
   
  #   closest_state = find_closest_state(client_time)
  #   temp_state = deep_copy(closest_state)

  #   player_number = @players.keys.index(user_id)
  #   player_key = player_number == 0 ? :player_1 : :player_2

  #   new_paddle_position = temp_state[:paddle_positions][player_key]
  #   case direction
  #   when -1
  #     new_paddle_position -= @config.dig(:settings, :paddle_speed)
  #   when 1
  #     new_paddle_position += @config.dig(:settings, :paddle_speed)
  #   end

  #   new_paddle_position = clamp(new_paddle_position, 0, 1)
  #   temp_state[:paddle_positions][player_key] = new_paddle_position

  #   replay_physics(temp_state, client_time, current_time)

  #   @state[:paddle_positions][player_key] = temp_state[:paddle_positions][player_key]
  #   @state[:ball_position] = temp_state[:ball_position]
  #   @state[:ball_velocity] = temp_state[:ball_velocity]
  # end

  # def find_closest_state(timestamp)
  #   @state_history.min_by { |state| (state[:timestamp] - timestamp).abs }
  # end

  # def replay_physics(state, start_time, end_time)
  #   delta_time = (end_time - start_time) / 1000.0
    
  #   state[:ball_position][:x] += state[:ball_velocity][:x] * delta_time
  #   state[:ball_position][:y] += state[:ball_velocity][:y] * delta_time
    
  #   if state[:ball_position][:y] <= -1 || state[:ball_position][:y] >= 1
  #     state[:ball_velocity][:y] *= -1
  #   end
    
  #   check_paddle_collisions(state)
  # end

  # def check_paddle_collisions(state)
  #   if state[:ball_position][:x] <= -0.9
  #     if (state[:ball_position][:y] - state[:paddle_positions][:player_1]).abs < 0.1
  #       state[:ball_velocity][:x] *= -1
  #     else
  #       lose_point(:player_1)
  #   end
    
  #   elsif state[:ball_position][:x] >= 0.9
  #     if (state[:ball_position][:y] - state[:paddle_positions][:player_2]).abs < 0.1
  #       state[:ball_velocity][:x] *= -1
  #     else
  #       lose_point(:player_2)
  #     end
  #   end
  # end

  # def lose_point(player_key)
  #   @state[:health_points][player_key] -= 1
  #   if @state[:health_points][player_key] == 0
  #     @state[:status] = :ended
  #   end
  #   @state[:ball_position] = { x: 0, y: 0 }
  #   @state[:ball_velocity] = { x: random_velocity, y: random_velocity }
  # end

  def player_idx(user_id)
    @players.keys.index(user_id)
  end

  def check_required_fields(*fields)
    fields.each do |field|
      raise BadRequest.new("Missing required field: #{field}") if field.nil? || field.empty?
    end
  end

  def current_time_ms
    (Time.now.to_f * 1000).to_i
  end

  # def random_velocity
  #   rand(-0.5..0.5) * @config.dig(:settings, :ball_speed)
  # end

  def deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  end

end