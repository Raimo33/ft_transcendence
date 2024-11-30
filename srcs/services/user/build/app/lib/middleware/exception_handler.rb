# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_handler.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/11/30 17:41:56 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'json'
require 'grpc'
require 'sequel'
require_relative '../custom_logger'

class ExceptionHandler
  SEQUEL_MAPPINGS = {
    Sequel::UniqueConstraintViolation       => GRPC::Core::StatusCodes::ALREADY_EXISTS,
    Sequel::ForeignKeyConstraintViolation   => GRPC::Core::StatusCodes::FAILED_PRECONDITION,
    Sequel::NotNullConstraintViolation      => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    Sequel::CheckConstraintViolation        => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    Sequel::SerializationFailure            => GRPC::Core::StatusCodes::ABORTED,
    Sequel::DatabaseConnectionError         => GRPC::Core::StatusCodes::UNAVAILABLE,
    Sequel::DatabaseError                   => GRPC::Core::StatusCodes::INTERNAL
  }.freeze

  GRPC_MAPPINGS = {
    GRPC::InvalidArgument   => [GRPC::Core::StatusCodes::INVALID_ARGUMENT,  "Invalid argument"],
    GRPC::Unauthenticated   => [GRPC::Core::StatusCodes::UNAUTHENTICATED,   "Authentication required"],
    GRPC::PermissionDenied  => [GRPC::Core::StatusCodes::PERMISSION_DENIED, "Permission denied"],
    GRPC::NotFound          => [GRPC::Core::StatusCodes::NOT_FOUND,         "Resource not found"],
    GRPC::AlreadyExists     => [GRPC::Core::StatusCodes::ALREADY_EXISTS,    "Resource already exists"]
  }.freeze

  CONSTRAINT_MESSAGES = {
    'pk_users'                => 'User already exists',
    'pk_friendships'          => 'Friendship already exists', 
    'unq_users_email'         => 'Email already in use',
    'unq_users_display_name'  => 'Display name already in use',
    'fk_friendships_user1'    => 'User not found',
    'fk_friendships_user2'    => 'User not found',
    'chk_email'               => 'Invalid email format',
    'chk_display_name'        => 'Invalid display name format'
  }.freeze

  def initialize(app)
    @app = app
    @logger = CustomLogger.instance.logger
  end

  def call(request, call)
    @app.call(request, call)
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
    when *SEQUEL_MAPPINGS.keys
      [SEQUEL_MAPPINGS[exception.class], map_constraint_message(exception)]
    when *GRPC_MAPPINGS.keys
      GRPC_MAPPINGS[exception.class]
    else
      [GRPC::Core::StatusCodes::INTERNAL, "Internal server error"]
    end
  end

  def map_constraint_message(exception)
    return exception.message unless exception.respond_to?(:constraint_name)
    CONSTRAINT_MESSAGES[exception.constraint_name] || "Validation error"
  end

end

