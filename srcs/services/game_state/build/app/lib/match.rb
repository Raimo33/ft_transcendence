# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match.rb                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/27 15:26:33 by craimond          #+#    #+#              #
#    Updated: 2024/12/27 18:48:41 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class Match
  attr_accessor :players, :state

  def initialize(id)
    @id = id
    @players = {}
    @state = {
      #TODO riempire con aas
      timestamp: Time.now.to_i,
    }
    @input_queue = []
  end

  def add_player(ws, user_id)
    @players[ws] = user_id
  end

  def remove_player(ws)
    @players.delete(ws)
  end

  def connected?(ws)
    @players.include?(ws)
  end

  def surrender(ws)
    #TODO
  end

  def queue_input(input)
    @input_queue << input
  end

  def update
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
    #TODO

end