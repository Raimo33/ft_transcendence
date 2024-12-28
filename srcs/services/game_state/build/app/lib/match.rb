# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match.rb                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/27 15:26:33 by craimond          #+#    #+#              #
#    Updated: 2024/12/29 00:45:30 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class Match
  attr_reader :players, :state

  def initialize(id)
    @id = id
    @players = {}
    @state = {
      #TODO riempire con aas
      status: :waiting,
      timestamp: Time.now.to_i,
    }
    @input_queue = []
  end

  def add_player(ws, user_id)
    @players[ws] = user_id
    if @players.size == 2
      @state[:status] = :ongoing
    end
  end

  def remove_player(ws)
    @players.delete(ws)
    @state[:status] = :waiting
  end

  def surrender_player(ws)
    @players.delete(ws)
    @state[:status] = :over
    #TODO declare winner
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
    #TODO update game state, check for collisions, check for game over etc
    state[:timestamp] = Time.now.to_i
  end
  
  private
  
  def process_inputs
    @input_queue.each do |input|
      apply_input(input)
    end
    @input_queue.clear
  end

  def apply_input(input)
    #TODO raise exception if input is invalid
  end

end