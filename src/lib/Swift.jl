module Swift

import JSON
using URIParser, Requests

export list_objects, get_object, download_object, upload_object

type SwiftAuthentication
  token::AbstractString
  url::AbstractString
  expires::DateTime
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

function authenticate( ; url::AbstractString = ENV["OS_AUTH_URL"] * "/" * "tokens", 
                         username::AbstractString = ENV["OS_USERNAME"], 
                         password::AbstractString = ENV["OS_PASSWORD"],
                         tenant_name::AbstractString = ENV["OS_TENANT_NAME"])
  auth = Dict("auth" => 
    Dict("passwordCredentials" => 
      Dict("username" => username, 
           "password" => password), 
      "tenantName" => tenant_name))

  response = Requests.post(url; json = auth)
  
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

function api_call(response_handler::Function, verb, path; 
                  url::AbstractString = ENV["OS_AUTH_URL"] * "/" * "tokens", 
                  username::AbstractString = ENV["OS_USERNAME"], 
                  password::AbstractString = ENV["OS_PASSWORD"],
                  tenant_name::AbstractString = ENV["OS_TENANT_NAME"],
                  headers = Dict(),
                  query = Dict(),
                  jsonResponse = false,
                  filepath = "",
                  fileoffset = 0,
                  content_length = filesize(filepath))
  global authentication

  if isnull(authentication) || get(authentication).expires < Dates.now()
    authentication::Nullable{SwiftAuthentication} = Nullable(authenticate( ; url = url, username = username, password = password, tenant_name = tenant_name))
  end

  token = get(authentication).token
  swift_url = get(authentication).url

  headers["X-Auth-Token"] = token

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
