# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_interceptor.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:01:43 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'pg'

class ExceptionInterceptor < GRPC::ServerInterceptor

  CONSTRAINT_MESSAGES = {
    'pk_users'                        => 'User already exists',
    'pk_friendships'                  => 'Friendship already exists', 
    'unq_users_email'                 => 'Email already in use',
    'unq_users_display_name'          => 'Display name already in use',
    'fk_friendships_user1'            => 'User not found',
    'fk_friendships_user2'            => 'User not found',
    'chk_friendships_different_users' => 'Cannot be friends with yourself',
    'chk_users_email'                 => 'Invalid email format',
    'chk_users_display_name'          => 'Invalid display name format'
  }.freeze

  def request_response(request: nil, call: nil, method: nil, &block)
    yield
  rescue StandardError => e
    handle_exception(e)
  end

  private

  def handle_exception(exception)
    raise exception if exception.is_a?(GRPC::BadStatus)

    status_code, message = case exception

    when PG::UniqueViolation, PG::ForeignKeyViolation, PG::NotNullViolation, PG::CheckViolation, PG::ExclusionViolation
      [GRPC::Core::StatusCodes::INVALID_ARGUMENT, map_constraint_violation(exception.result)]
    else
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      [GRPC::Core::StatusCodes::INTERNAL, "Internal server error"]

    raise GRPC::BadStatus.new(status_code, message)
  end

  def map_constraint_violation(result)
    constraint_name = result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    CONSTRAINT_MESSAGES[constraint_name] || "Validation error"
  end

end

