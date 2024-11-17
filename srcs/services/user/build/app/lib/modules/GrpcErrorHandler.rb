# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcErrorHandler.rb                                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/17 16:22:25 by craimond          #+#    #+#              #
#    Updated: 2024/11/17 16:23:14 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module GrpcErrorHandler
  class GrpcError               < StandardError;  end

  class InvalidArgumentError    < GrpcError;      end
  class RateLimitError          < GrpcError;      end
  class ServiceUnavailableError < GrpcError;      end
  class InternalError           < GrpcError;      end

  private

  def handle_grpc_call(operation_name)
    @logger.debug("Starting #{operation_name}")
    
    yield
  rescue GRPC::InvalidArgument => e
    @logger.error("Invalid argument for #{operation_name}: #{e.message}")
    raise InvalidArgumentError, "Invalid input: #{e.message}"
  rescue GRPC::ResourceExhausted => e
    @logger.error("Rate limit exceeded for #{operation_name}: #{e.message}")
    raise RateLimitError, "Too many attempts: #{e.message}"
  rescue GRPC::Unavailable, GRPC::DeadlineExceeded => e
    @logger.error("Service unavailable during #{operation_name}: #{e.message}")
    raise ServiceUnavailableError, "Service currently unavailable: #{e.message}"
  rescue GRPC::Internal => e
    @logger.error("Internal error during #{operation_name}: #{e.message}")
    raise InternalError, "Internal error occurred"
  rescue GRPC::BadStatus => e
    @logger.error("Unexpected gRPC error during #{operation_name}: #{e.message}")
    raise GrpcError, "Unexpected error: #{e.message}"
  end
end