module Swift

import JSON
using URIParser, Requests

export list_objects, get_object, download_object, upload_object

abstract AbstractSwiftAuthentication

type NoSwiftAuthentication <: AbstractSwiftAuthentication
end

type ReadOnlySwiftAuthentication <: AbstractSwiftAuthentication
  url::AbstractString
end

type SwiftAuthentication <: AbstractSwiftAuthentication
  token::AbstractString
  url::AbstractString
  expires::DateTime
end

abstract AbstractAuthInfo

type AuthInfo <: AbstractAuthInfo
  url::AbstractString 
  username::AbstractString
  password::AbstractString
  tenant_name::AbstractString
end

type ReadOnlyAuthInfo <: AbstractAuthInfo
  url::AbstractString
end

type NoAuthInfo <: AbstractAuthInfo
end

authentication = Nullable{SwiftAuthentication}()

function list_objects(container::AbstractString)
  api_call("GET", container; jsonResponse = true) do response, body
    map(JSON.parse(body)) do obj
      obj["name"]
    end
  end
end

function stat(container, object)
  api_call("HEAD", container * "/" * object) do response, body
    return response.headers
  end
end

function exists(container, object)
  return stat(container, object)["status_code"] != "404"
end

function get_object(container::AbstractString, object::AbstractString)
  api_call("GET", container * "/" * object) do response, body
    body
  end
end

function download_object(container::AbstractString, object::AbstractString; filepath=joinpath(pwd(),object))
  api_call("GET", container * "/" * object; filepath=filepath) do response, body
    response
  end
end

function upload_object(container::AbstractString, object::AbstractString; filepath=joinpath(pwd(),object), 
                                                                          segment_size=1024*1024*500, # default to 500MB segments
                                                                          segment_container=container * "_segments")

#  run(`swift upload --segment-size=$segment_size --segment-container=$segment_container --object-name=$object $container $filepath`)
#  return

  # TODO: the following is blocked by some pretty terrible performance when communicating over
  # https vs http. This seems to have been reported on the following issue:
  #   https://github.com/JuliaWeb/Requests.jl/issues/117
  # There was apparently difficulty producing the bug with the information provided in the orignal
  # report. I was able to reproduce it using a modified version of their test suite code for doing
  # chunked uploading and added a comment with that. Until this is resolved, we're going to default
  # to an ugly hack of assuming the python-swiftclient command line tool has been installed and using
  # that to upload a file. 
  totalbytes = filesize(filepath)
  if totalbytes > segment_size
    segment = 0
    offset = 0
    segment_prefix = segment_container * "/" * object * "/"
    while offset < totalbytes
      segment_index = dec(segment, 7) # pad segment number to 7 digits
      api_call("PUT", segment_prefix * segment_index; filepath=filepath, fileoffset=offset, content_length=segment_size) do response, body
        response
      end
      segment += 1
      offset = segment * segment_size
    end
    headers = Dict("X-Object-Manifest" => segment_prefix)
    api_call("PUT", container * "/" * object; headers = headers) do response, body
      response
    end
  else
    api_call("PUT", container * "/" * object; filepath=filepath) do response, body
      response
    end
  end
end

function authenticate(auth_info::AuthInfo)
  auth = Dict("auth" => 
    Dict("passwordCredentials" => 
      Dict("username" => auth_info.username, 
           "password" => auth_info.password), 
      "tenantName" => auth_info.tenant_name))

  response = Requests.post(auth_info.url; json = auth)
  
  if response.status == 200
    json_obj = JSON.parse(readall(response))
    token = json_obj["access"]["token"]["id"]
    expires = DateTime(json_obj["access"]["token"]["expires"], "yyyy-mm-ddTHH:MM:SSZ")
    swift_service = first(filter(x -> x["type"] == "object-store", json_obj["access"]["serviceCatalog"]))
    swift_url = first(map(x -> x["publicURL"], swift_service["endpoints"]))

    return SwiftAuthentication(token, swift_url, expires)
  else
    error("Could not authenticate to $tenant_name with $username")
  end
end
authenticate(auth_info::ReadOnlyAuthInfo) = ReadOnlySwiftAuthentication(auth_info.url)
authenticate(auth_info::NoAuthInfo) = NoSwiftAuthentication()

check_credentials(creds...) = isempty(setdiff(creds, keys(ENV)))
function get_auth_info()
  if check_credentials("OS_AUTH_URL", "OS_USERNAME", "OS_PASSWORD", "OS_TENANT_NAME")
    AuthInfo(ENV["OS_AUTH_URL"] * "/" * "tokens", ENV["OS_USERNAME"], ENV["OS_PASSWORD"], ENV["OS_TENANT_NAME"])
  elseif check_credentials("OS_SWIFT_URL")
    ReadOnlyAuthInfo(ENV["OS_SWIFT_URL"])
  else
    return NoAuthInfo()
  end
end

function set_auth_headers(auth::SwiftAuthentication, headers)
  headers["X-Auth-Token"] = auth.token
end
set_auth_headers(auth::ReadOnlySwiftAuthentication, headers) = return
set_auth_headers{T <: AbstractSwiftAuthentication}(auth::Nullable{T}, headers) = 
  set_auth_headers(get(auth), headers)

expired(auth::ReadOnlySwiftAuthentication) = false
expired(auth::SwiftAuthentication) = auth.expires < Dates.now()
expired{T <: AbstractSwiftAuthentication}(auth::Nullable{T}) = expired(get(authentication))

function api_call(response_handler::Function, verb, path; 
                  auth_info = get_auth_info(),
                  headers = Dict(),
                  query = Dict(),
                  jsonResponse = false,
                  filepath = "",
                  fileoffset = 0,
                  content_length = filesize(filepath))
  global authentication

  if isnull(authentication) || expired(authentication)
    authentication = Nullable(authenticate(auth_info))
  end

  if typeof(authentication) == Nullable{NoSwiftAuthentication}
    return ""
  end

  swift_url = get(authentication).url
  set_auth_headers(authentication, headers)

  if jsonResponse
    query["format"] = "json"
  end

  if verb in ["PUT", "POST"]
    headers["Content-Length"] = string(content_length)
  end

  if filepath == ""
    response = Requests.do_request(URI(swift_url * "/" * path), verb, headers = headers, query = query)

    response_handler(response, readall(response))
  else
    write_body = true
    if verb in ["GET", "HEAD"]
      stream_handler = readstream
    else
      stream_handler = writestream
      write_body = false
      headers["Transfer-Encoding"] = "chunked"
    end
    stream = Requests.do_stream_request(URI(swift_url * "/" * path), verb, headers = headers, query = query, write_body = write_body)
    stream_handler(stream, filepath; fileoffset = fileoffset, maxbytes = content_length)

    response_handler(stream.response, readall(stream.response))
  end
end

function readstream(stream, filepath::AbstractString; fileoffset = 0,
                                                      maxbytes = filesize(filepath) - fileoffset, 
                                                      chunksize = 1024*1024)
  open(filepath, "w") do file
    while !eof(stream)
      write(file, readavailable(stream))
    end
  end  
end

function writestream(stream, filepath::AbstractString; fileoffset = 0, 
                                                       maxbytes = filesize(filepath) - fileoffset, 
                                                       chunksize = 1024*1024)
  remaining = maxbytes

  open(filepath,"r") do f
    seek(f, fileoffset)

    while !eof(f) && remaining > 0
      numbytes = min(chunksize,remaining)
      chunk = read(f,numbytes)
      write_chunked(stream,chunk)
      remaining -= numbytes
    end
    write_chunked(stream,"")
  end
end

end
