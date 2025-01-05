# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exceptions.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/03 11:49:04 by craimond          #+#    #+#              #
#    Updated: 2025/01/04 00:09:27 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class HttpError < StandardError
  attr_reader :status, :message

  def initialize(status, message)
    @status = status
    super(message)
  end
end

class BadRequest < HttpError
  def initialize(message = "Bad Request")
    super(400, message)
  end
end

class Unauthorized < HttpError
  def initialize(message = "Unauthorized")
    super(401, message)
  end
end

class PaymentRequired < HttpError
  def initialize(message = "Payment Required")
    super(402, message)
  end
end

class Forbidden < HttpError
  def initialize(message = "Forbidden")
    super(403, message)
  end
end

class NotFound < HttpError
  def initialize(message = "Not Found")
    super(404, message)
  end
end

class MethodNotAllowed < HttpError
  def initialize(message = "Method Not Allowed")
    super(405, message)
  end
end

class NotAcceptable < HttpError
  def initialize(message = "Not Acceptable")
    super(406, message)
  end
end

class ProxyAuthenticationRequired < HttpError
  def initialize(message = "Proxy Authentication Required")
    super(407, message)
  end
end

class RequestTimeout < HttpError
  def initialize(message = "Request Timeout")
    super(408, message)
  end
end

class Conflict < HttpError
  def initialize(message = "Conflict")
    super(409, message)
  end
end

class Gone < HttpError
  def initialize(message = "Gone")
    super(410, message)
  end
end

class LengthRequired < HttpError
  def initialize(message = "Length Required")
    super(411, message)
  end
end

class PreconditionFailed < HttpError
  def initialize(message = "Precondition Failed")
    super(412, message)
  end
end

class PayloadTooLarge < HttpError
  def initialize(message = "Payload Too Large")
    super(413, message)
  end
end

class UriTooLong < HttpError
  def initialize(message = "URI Too Long")
    super(414, message)
  end
end

class UnsupportedMediaType < HttpError
  def initialize(message = "Unsupported Media Type")
    super(415, message)
  end
end

class RangeNotSatisfiable < HttpError
  def initialize(message = "Range Not Satisfiable")
    super(416, message)
  end
end

class ExpectationFailed < HttpError
  def initialize(message = "Expectation Failed")
    super(417, message)
  end
end

class ImATeapot < HttpError
  def initialize(message = "I'm a Teapot")
    super(418, message)
  end
end

class UnprocessableEntity < HttpError
  def initialize(message = "Unprocessable Entity")
    super(422, message)
  end
end

class Locked < HttpError
  def initialize(message = "Locked")
    super(423, message)
  end
end

class FailedDependency < HttpError
  def initialize(message = "Failed Dependency")
    super(424, message)
  end
end

class TooEarly < HttpError
  def initialize(message = "Too Early")
    super(425, message)
  end
end

class UpgradeRequired < HttpError
  def initialize(message = "Upgrade Required")
    super(426, message)
  end
end

class PreconditionRequired < HttpError
  def initialize(message = "Precondition Required")
    super(428, message)
  end
end

class TooManyRequests < HttpError
  def initialize(message = "Too Many Requests")
    super(429, message)
  end
end

class RequestHeaderFieldsTooLarge < HttpError
  def initialize(message = "Request Header Fields Too Large")
    super(431, message)
  end
end

class UnavailableForLegalReasons < HttpError
  def initialize(message = "Unavailable For Legal Reasons")
    super(451, message)
  end
end

class InternalServerError < HttpError
  def initialize(message = "Internal Server Error")
    super(500, message)
  end
end

class NotImplemented < HttpError
  def initialize(message = "Not Implemented")
    super(501, message)
  end
end

class BadGateway < HttpError
  def initialize(message = "Bad Gateway")
    super(502, message)
  end
end

class ServiceUnavailable < HttpError
  def initialize(message = "Service Unavailable")
    super(503, message)
  end
end

class GatewayTimeout < HttpError
  def initialize(message = "Gateway Timeout")
    super(504, message)
  end
end

class HttpVersionNotSupported < HttpError
  def initialize(message = "HTTP Version Not Supported")
    super(505, message)
  end
end

class VariantAlsoNegotiates < HttpError
  def initialize(message = "Variant Also Negotiates")
    super(506, message)
  end
end

class InsufficientStorage < HttpError
  def initialize(message = "Insufficient Storage")
    super(507, message)
  end
end

class LoopDetected < HttpError
  def initialize(message = "Loop Detected")
    super(508, message)
  end
end

class NotExtended < HttpError
  def initialize(message = "Not Extended")
    super(510, message)
  end
end

class NetworkAuthenticationRequired < HttpError
  def initialize(message = "Network Authentication Required")
    super(511, message)
  end
end