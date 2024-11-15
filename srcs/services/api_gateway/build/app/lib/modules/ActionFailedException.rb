# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ActionFailedException.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/26 08:37:11 by craimond          #+#    #+#              #
#    Updated: 2024/11/15 20:34:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module ActionFailedException

  class BaseError < StandardError
    attr_reader :status_code

    def initialize
      @status_code = Mapper::EXCEPTION_TO_STATUS_CODE_MAP[self.class] || 500
      super(self.class.name.split("::").last)
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
