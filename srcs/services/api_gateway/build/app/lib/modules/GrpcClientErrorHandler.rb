# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClientErrorHandler.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/17 16:22:25 by craimond          #+#    #+#              #
#    Updated: 2024/11/20 04:05:46 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative "ServerException"

module GrpcClientErrorHandler

  private

  def handle_grpc_call
    
    yield
  rescue GRPC::InvalidArgument => e
    @logger.error("Invalid argument for #{operation_name}: #{e.message}")
    raise ServerException::BadRequest.new(e.message)
  rescue GRPC::ResourceExhausted => e
    @logger.error("Rate limit exceeded for #{operation_name}: #{e.message}")
    raise ServerException::TooManyRequests.new(e.message)
  rescue GRPC::Unavailable, GRPC::DeadlineExceeded => e
    @logger.error("Service unavailable during #{operation_name}: #{e.message}")
    raise ServerException::ServiceUnavailable.new(e.message)
  rescue GRPC::Internal, GRPC::BadStatus, GRPC::Unknown => e
    @logger.error("Internal error during #{operation_name}: #{e.message}")
    raise ServerException::InternalServerError.new(e.message)
  end
end