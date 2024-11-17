# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ServerException.rb                                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/17 20:26:55 by craimond          #+#    #+#              #
#    Updated: 2024/11/17 20:26:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module ServerException

  EXCEPTIONS_TO_STATUS_CODE_MAP = {
    BadRequest         => 400,
    Unauthorized       => 401,
    Forbidden          => 403,
    NotFound           => 404,
    MethodNotAllowed   => 405,
    RequestTimeout     => 408,
    Conflict           => 409,
    TooManyRequests    => 429,
    InternalServer     => 500,
    NotImplemented     => 501,
    BadGateway         => 502,
    ServiceUnavailable => 503,
    GatewayTimeout     => 504
  }.freeze

  class BaseError < StandardError
    attr_reader :status_code

    def initialize(message = nil)
      @status_code = EXCEPTIONS_TO_STATUS_CODE_MAP[self.class] || 500
      super(message || self.class.name.split('::').last)
    end
  end

  class BadRequest         < BaseError; end
  class Unauthorized       < BaseError; end
  class Forbidden          < BaseError; end
  class NotFound           < BaseError; end
  class MethodNotAllowed   < BaseError; end
  class RequestTimeout     < BaseError; end
  class Conflict           < BaseError; end
  class TooManyRequests    < BaseError; end
  class InternalServer     < BaseError; end
  class NotImplemented     < BaseError; end
  class BadGateway         < BaseError; end
  class ServiceUnavailable < BaseError; end
  class GatewayTimeout     < BaseError; end

end