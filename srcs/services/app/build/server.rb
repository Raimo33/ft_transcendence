# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 14:27:54 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 12:00:28 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'falcon'
require 'openapi_first'
require 'json'
require_relative 'shared/config_handler'
require_relative 'shared/exceptions'

class Server

  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    params = parsed_request[:params]
    operationId = parsed_request[:operationId]
    
    send(operation_id, params)
  rescue NoMethodError => e
    raise NotFound.new("Operation not found")
  end

  private

  def ping(params)
    [200, { 'Content-Type' => 'application/text' }, [{ 'pong...fu!' }]]
  end

  def registerUser(params)

    body = {
      user_id:
    }

    [201, {}, [JSON.generate(body)]]
  end

  def getUserPublicProfile(params)

  def getUserStatus(params)

  def getUserMatches(params)

  def getUserTournaments(params)

  def deleteAccount(params)

  def getUserPrivateProfile(params)

  def updateProfile(params)

  def enableTFA(params)

  def disableTFA(params)

  def submitTFACode(params)

  def loginUser(params)

  def refreshUserSessionToken(params)

  def logoutUser(params)

  def addFriend(params)

  def getFriends(params)

  def removeFriend(params)

  def acceptFriendRequest(params)

  def rejectFriendRequest(params)

  def startMatchmaking(params)

  def stopMatchmaking(params)

  def challengeFriend(params)

  def getMatch(params)

  def leaveMatch(params)

  def acceptMatchInvitation(params)

  def declineMatchInvitation(params)

  def createTournament(params)

  def getTournament(params)

  def cancelTournament(params)

  def joinTournament(params)

  def leaveTournament(params)

end