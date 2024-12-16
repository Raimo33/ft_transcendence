# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_interceptor.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/12/16 19:13:07 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'pg'
require 'jwt'

class ExceptionInterceptor < GRPC::ServerInterceptor

  def request_response(request: nil, call: nil, method: nil, &block)
    yield
  rescue StandardError => e
    handle_exception(e)
  end
  
  private

  CONSTRAINT_MESSAGES = {
    'pk_matches'                      => "Match already exists",
    'fk_matches_creatorid'            => "User not found",
    'fk_matches_tournamentid'         => "Tournament not found",
    'fk_friendships_user_id_1'        => "Friendship not found",
    'fk_friendships_user_id_2'        => "Friendship not found",
    'unq_matches_tournamentid'        => "Tournament already exists",
    'chk_matches_startedat'           => "Match cannot start in the past",
    'chk_matches_endedat'             => "Match cannot end before it starts",
    'chk_friendships_different_users' => "Cannot be friends with yourself",
  }.freeze

  EXCEPTION_MAP = {
    PG::ConnectionBad             => [GRPC::Core::StatusCodes::UNAVAILABLE, "Database connection error"],
    ConnectionPool::TimeoutError  => [GRPC::Core::StatusCodes::UNAVAILABLE, "Connection timeout"],
  }.freeze

  def handle_exception(exception)
    raise exception if exception.is_a?(GRPC::BadStatus)

    status_code, message = case exception

    when PG::UniqueViolation
      [GRPC::Core::StatusCodes::ALREADY_EXISTS, map_constraint_violation(exception.result)]
    when PG::ForeignKeyViolation, PG::NotNullViolation, PG::CheckViolation, PG::ExclusionViolation
      [GRPC::Core::StatusCodes::INVALID_ARGUMENT, map_constraint_violation(exception.result)]
    else
      EXCEPTION_MAP[exception.class]
    end

    if status_code.nil?
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      status_code = GRPC::Core::StatusCodes::INTERNAL
      message = "Internal server error"
    end

    raise GRPC::BadStatus.new(status_code, message)
  end

  def map_constraint_violation(result)
    constraint_name = result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    CONSTRAINT_MESSAGES[constraint_name] || "Validation error"
  end

end

