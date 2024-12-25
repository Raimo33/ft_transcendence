  #to avoid keeping memcached cache in disk, 'token_invalid_before' is set upon login / first user encounter
  #and then checked upon every request, a missing 'token_invalid_before' key is equivalent to an invalid token
  #this way even if the server crashes, there's no risk, but just the user having to login again