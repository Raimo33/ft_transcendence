# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_interceptor.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:16:39 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'json'
require 'pg'
require 'jwt'

class ExceptionInterceptor < GRPC::ServerInterceptor

  PG_MAPPINGS = {
    PG::UniqueViolation        => GRPC::Core::StatusCodes::ALREADY_EXISTS,
    PG::ForeignKeyViolation    => GRPC::Core::StatusCodes::FAILED_PRECONDITION,
    PG::NotNullViolation       => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    PG::CheckViolation         => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    PG::SerializationFailure   => GRPC::Core::StatusCodes::ABORTED,
    PG::ConnectionBad          => GRPC::Core::StatusCodes::UNAVAILABLE,
    PG::Error                  => GRPC::Core::StatusCodes::INTERNAL,
    PG::Pool::Error            => GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED
  }.freeze

  GRPC_MAPPINGS = {
    GRPC::InvalidArgument   => [GRPC::Core::StatusCodes::INVALID_ARGUMENT,  "Invalid argument"],
    GRPC::Unauthenticated   => [GRPC::Core::StatusCodes::UNAUTHENTICATED,   "Authentication required"],
    GRPC::PermissionDenied  => [GRPC::Core::StatusCodes::PERMISSION_DENIED, "Permission denied"],
    GRPC::NotFound          => [GRPC::Core::StatusCodes::NOT_FOUND,         "Resource not found"],
    GRPC::AlreadyExists     => [GRPC::Core::StatusCodes::ALREADY_EXISTS,    "Resource already exists"]
  }.freeze

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

  def initialize(app)
    @app = app
  end

  def request_response(request: nil, call: nil, method: nil)
    yield
  rescue StandardError => e
    handle_exception(e)
  end

  private

  def handle_exception(exception)
    status_code, message = map_exception(exception)
    raise GRPC::BadStatus.new(status_code, message)
  end

  def map_exception(exception)
    case exception
    when *PG_MAPPINGS.keys
      [PG_MAPPINGS[exception.class], map_pg_message(exception)]
    when *GRPC_MAPPINGS.keys
      GRPC_MAPPINGS[exception.class]      
    else
      [GRPC::Core::StatusCodes::INTERNAL, "Internal server error"]
    end
  end

  def map_pg_message(exception)
    return exception.message unless exception.respond_to?(:result)
    
    case exception
    when PG::UniqueViolation, PG::ForeignKeyViolation, PG::NotNullViolation, PG::CheckViolation
      constraint_name = exception.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      CONSTRAINT_MESSAGES[constraint_name] || "Validation error"
    when PG::Pool::Error
      "Connection pool exhausted"
    else
      exception.message
    end
  end

end

