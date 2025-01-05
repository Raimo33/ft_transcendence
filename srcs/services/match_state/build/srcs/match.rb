# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match.rb                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/27 15:26:33 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 17:36:53 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'config_handler'
require_relative 'exceptions'

class Match
  attr_reader :players, :state

  CENTER = 0.5
  COURT_BOUNDS = (0..1).freeze
  VELOCITY_RANGE = (-0.5..0.5).freeze

  PADDLE_LENGTH = 0.3
  PADDLE_HALF_LENGTH = PADDLE_LENGTH / 2
  PADDLE_RANGE = ((PADDLE_HALF_LENGTH)..(1 - PADDLE_HALF_LENGTH)).freeze

  @config = ConfigHandler.instance.config

  def self.max_hp
    @max_hp ||= @config.dig(:settings, :max_hp)
  end

  STARTING_match_state = {
    ball_position: [0.5, 0.5],
    ball_velocity: [],
    paddle_positions: [0.5, 0.5],
    health_points: [max_hp, max_hp],
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

    reset_ball
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
    @state[:health_points][idx] = 0
    @state[:status] = :ended
  end

  def player_connected?(user_id)
    @players.keys.include?(user_id)
  end

  def queue_input(input)
    @input_queue << input
  end

  def update
    return unless @state[:status] == :ongoing
    
    current_time = current_time_ms
    process_inputs(current_time)
    
    @state_history << deep_copy(@state)
    @state_history.reject! do |state|
      current_time - state[:timestamp] > @config.dig(:server, :max_lag_compensation)
    end
  
    @state[:timestamp] = current_time
  end

  private

  def process_inputs(current_time)
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
    raise GRPC::InvalidArgument.new('User not in match') unless @players.keys.include?(user_id)
    raise GRPC::InvalidArgument.new('Invalid direction format') unless [-1, 0, 1].include?(direction)
    raise GRPC::InvalidArgument.new('Invalid timestamp format') unless client_time.is_a?(Integer)
    return if direction.zero?

    lag = current_time - client_time
    return if lag > @config.dig(:server, :max_lag_compensation)
   
    closest_state = find_closest_state(client_time)
    temp_state = deep_copy(closest_state)

    player_idx = @players.keys.index(user_id)

    new_paddle_position = temp_state[:paddle_positions][player_idx]
    case direction
    when 
      new_paddle_position -= @config.dig(:settings, :paddle_speed)
    when 1
      new_paddle_position += @config.dig(:settings, :paddle_speed)
    end

    new_paddle_position.clamp!(PADDLE_RANGE.first, PADDLE_RANGE.last)
    temp_state[:paddle_positions][player_idx] = new_paddle_position

    replay_physics(temp_state, client_time, current_time)

    @state[:paddle_positions][player_idx] = temp_state[:paddle_positions][player_idx]
    @state[:ball_position] = temp_state[:ball_position]
    @state[:ball_velocity] = temp_state[:ball_velocity]
  end

  def find_closest_state(timestamp)
    @state_history.min_by { |state| (state[:timestamp] - timestamp).abs }
  end

  def replay_physics(state, start_time, end_time)
    delta_time = (end_time - start_time) / 1000.0
    
    state[:ball_position][0] += state[:ball_velocity][0] * delta_time
    state[:ball_position][1] += state[:ball_velocity][1] * delta_time
    
    unless COURT_BOUNDS.cover?(state[:ball_position][1])
      state[:ball_velocity][1] *= -1
    end
    
    check_paddle_collisions(state)
  end

  def check_paddle_collisions(state)
    ball_x, ball_y = state[:ball_position]
    left_paddle_center, right_paddle_center = state[:paddle_positions]
  
    if ball_x <= -PADDLE_BOUNDARY
      check_collision(ball_y, left_paddle_center, 0, state)
    elsif ball_x >= PADDLE_BOUNDARY
      check_collision(ball_y, right_paddle_center, 1, state)
    end
  end
  
  private
  
  def check_collision(ball_y, paddle_center, player_idx, state)
    paddle_min = paddle_center - PADDLE_HALF_LENGTH
    paddle_max = paddle_center + PADDLE_HALF_LENGTH
    
    if ball_y.between?(paddle_min, paddle_max)
      state[:ball_velocity][0] *= -1
    else
      lose_point(player_idx)
    end
  end

  def lose_point(player_idx)
    @state[:health_points][player_idx] -= 1
  
    if @state[:health_points][player_idx] == 0
      @state[:status] = :ended
    else
      reset_ball
    end
  end

  def reset_ball
    @state[:ball_position] = [0.5, 0.5]
    velocity = [random_direction, random_direction]
    @state[:ball_velocity] = velocity
  end

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

  def random_direction
    speed = @config.dig(:settings, :ball_speed)
    dir = rand(VELOCITY_RANGE) 
    dir = rand(VELOCITY_RANGE) while dir.zero?
    dir * speed
  end

  def deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  end

end