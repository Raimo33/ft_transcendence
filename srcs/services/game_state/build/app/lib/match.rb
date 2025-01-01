# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match.rb                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/27 15:26:33 by craimond          #+#    #+#              #
#    Updated: 2025/01/01 13:53:46 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'config_handler'

class Match
  attr_reader :players, :state
  attr_accessor :state_sequence

  @config = ConfigHandler.instance.config

  def initialize(id)
    @id = id
    @players = {}
    @paused_players = {}
    @state = {
      ball_position: { x: 0, y: 0 },
      ball_velocity: { x: 0, y: 0 },
      paddle_positions: {
        player_0: 0.5,
        player_1: 0.5,
      },
      health_points: {
        player_0: @config.dig(:settings, :max_health_points),
        player_1: @config.dig(:settings, :max_health_points),
      },
      status: :waiting,
      timestamp: current_time_ms,
    }
    @input_queue = []
    @state_history = []
    @state_sequence = 0
  end

  def add_player(user_id, ws)
    @players[user_id] = ws
    @paused_players.delete(user_id)
    if @players.size == 2 && @state[:status] == :waiting
      @state[:status] = :ongoing
    end
  end

  def pause_player(user_id)
    @paused_players[user_id] = @players[user_id]
    @state[:status] = :waiting
  end

  def surrender_player(user_id)
    player_role = user_id == @players[0] ? :player_0 : :player_1
    @status[:health_points][player_role] = 0
    @state[:status] = :over
  end

  def queue_input(input)
    @input_queue << input
  end

  def update
    return unless @status == :ongoing
    
    current_time = current_time_ms
    process_inputs(current_time)
    
    @state_history << deep_copy(@state)
    @state_history.reject! { |s| current_time - s[:timestamp] > @config.dig(:game_server, :max_lag_compensation) }
  
    @state[:timestamp] = current_time
  end

  private

  def process_inputs
    @input_queue.sort_by! { |input| input[:timestamp] }
    @input_queue.each do |input|
      apply_input(input, current_time)
    end
    @input_queue.clear
  end

  def apply_input(input, current_time)
    user_id = input[:user_id]
    client_time = input[:timestamp]
    direction = input[:direction]
    check_required_fields(user_id, client_time, direction)
    raise Grpc::InvalidArgument.new('User not in match') unless @players.keys.include?(user_id)
    raise Grpc::InvalidArgument.new('Invalid direction format') unless [-1, 0, 1].include?(direction)
    raise Grpc::InvalidArgument.new('Invalid timestamp format') unless client_time.is_a?(Integer)

    server_delay = current_time - client_time
    return if server_delay > @config.dig(:game_server, :max_lag_compensation)
   
    closest_state = find_closest_state(client_time)
    temp_state = deep_copy(closest_state)

    player_number = @players.keys.index(user_id)
    player_key = player_number == 0 ? :player_0 : :player_1

    new_paddle_position = temp_state[:paddle_positions][player_key]
    case direction
    when -1
      new_paddle_position -= @config.dig(:settings, :paddle_speed)
    when 1
      new_paddle_position += @config.dig(:settings, :paddle_speed)
    end

    new_paddle_position = clamp(new_paddle_position, 0, 1)
    temp_state[:paddle_positions][player_key] = new_paddle_position

    replay_physics(temp_state, client_time, current_time)

    @state[:paddle_positions][player_key] = temp_state[:paddle_positions][player_key]
    @state[:ball_position] = temp_state[:ball_position]
    @state[:ball_velocity] = temp_state[:ball_velocity]
  end

  def find_closest_state(timestamp)
    @state_history.min_by { |state| (state[:timestamp] - timestamp).abs }
  end

  def replay_physics(state, start_time, end_time)
    delta_time = (end_time - start_time) / 1000.0
    
    state[:ball_position][:x] += state[:ball_velocity][:x] * delta_time
    state[:ball_position][:y] += state[:ball_velocity][:y] * delta_time
    
    if state[:ball_position][:y] <= -1 || state[:ball_position][:y] >= 1
      state[:ball_velocity][:y] *= -1
    end
    
    check_paddle_collisions(state)
  end

  def check_paddle_collisions(state)
    if state[:ball_position][:x] <= -0.9
      if (state[:ball_position][:y] - state[:paddle_positions][:player_0]).abs < 0.1
        state[:ball_velocity][:x] *= -1
      else
        lose_point(:player_0)
    end
    
    elsif state[:ball_position][:x] >= 0.9
      if (state[:ball_position][:y] - state[:paddle_positions][:player_1]).abs < 0.1
        state[:ball_velocity][:x] *= -1
      else
        lose_point(:player_1)
      end
    end
  end

  def lose_point(player_key)
    @state[:health_points][player_key] -= 1
    if @state[:health_points][player_key] == 0
      @state[:status] = :over
    end
    @state[:ball_position] = { x: 0, y: 0 }
    @state[:ball_velocity] = { x: random_velocity, y: random_velocity }
  end

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end
  
  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

  def current_time_ms
    (Time.now.to_f * 1000).to_i
  end

  def random_velocity
    rand(-0.5..0.5) * @config.dig(:settings, :ball_speed)
  end

  def deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  end

end