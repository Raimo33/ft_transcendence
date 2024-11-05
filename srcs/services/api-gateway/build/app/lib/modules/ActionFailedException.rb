# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exceptions.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/26 08:37:11 by craimond          #+#    #+#              #
#    Updated: 2024/11/03 19:40:34 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module ActionFailedException

  class ActionFailedException < StandardError
    attr_reader :status_code

    def initialize(message = nil, status_code = self.class::STATUS_CODE)
      super(message)
      @status_code = status_code
    end
  end

  class BadRequest         < ActionFailedException; STATUS_CODE = 400; end
  class Unauthorized       < ActionFailedException; STATUS_CODE = 401; end
  class Forbidden          < ActionFailedException; STATUS_CODE = 403; end
  class NotFound           < ActionFailedException; STATUS_CODE = 404; end
  class MethodNotAllowed   < ActionFailedException; STATUS_CODE = 405; end
  class RequestTimeout     < ActionFailedException; STATUS_CODE = 408; end
  class URITooLong         < ActionFailedException; STATUS_CODE = 414; end
  class TooManyRequests    < ActionFailedException; STATUS_CODE = 429; end
  class Conflict           < ActionFailedException; STATUS_CODE = 409; end
  class InternalServer     < ActionFailedException; STATUS_CODE = 500; end
  class NotImplemented     < ActionFailedException; STATUS_CODE = 501; end
  class BadGateway         < ActionFailedException; STATUS_CODE = 502; end
  class ServiceUnavailable < ActionFailedException; STATUS_CODE = 503; end
  class GatewayTimeout     < ActionFailedException; STATUS_CODE = 504; end
    
end