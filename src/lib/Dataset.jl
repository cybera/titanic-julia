# look for csv
# look for script
# generate csv
# load and return csv

module Dataset
  using DataFrames
  import Main.Config
  import Swift

  module Build
    using DataFrames
    import Main.Config
    import Dataset

    for fname in readdir(Config.Path.dataset_generators)
      include(joinpath(Config.Path.dataset_generators, fname))
    end
  end

  function fetch(id::AbstractString)
    f, cached = from_cache(id)
    if !cached
      println("$id: Building...")

      dataset_expr = parse("$id()")
      f = Build.eval(dataset_expr)

      cache_local(id, f)
    end

    return f
  end
  fetch(id::Symbol) = fetch(string(id))

  function from_cache(id::AbstractString)
    f, cached, source = from_filesystem(id)
    if !cached
      f, cached, source = from_swift(id)
    end
    return f, cached, source
  end

  function from_filesystem(id::AbstractString;pathonly=false)
    path, cached, source = local_path(id)
    if cached
      println("$id: Found $source version")
      return readtable(path), cached, source
    else
      return DataFrame(), cached, source
    end
  end

  function from_swift(id::AbstractString)
    csv_name = "$id.csv"
    cached_object = join([Config.Swift.cache_prefix, csv_name], "/")
    raw_object = join([Config.Swift.raw_prefix, csv_name], "/")
    if Swift.exists(Config.Swift.root_container, cached_object)
      cached_path = joinpath(Config.Path.dataset_cache, csv_name)
      Swift.download_object(Config.Swift.root_container, cached_object, filepath=cached_path)
      println("$id: Found uploaded cached version")
      return readtable(cached_path), true, :cached
    elseif Swift.exists(Config.Swift.root_container, raw_object)
      raw_path = joinpath(Config.Path.dataset_raw, csv_name)
      Swift.download_object(Config.Swift.root_container, raw_object, filepath=raw_path)
      println("$id: Found uploaded raw version")
      return readtable(raw_path), true, :raw
    else
      return DataFrame(), false, :none
    end
  end

  function local_path(id::AbstractString)
    csv_name = "$id.csv"
    cached_path = joinpath(Config.Path.dataset_cache, csv_name)
    raw_path = joinpath(Config.Path.dataset_raw, csv_name)
    if ispath(cached_path)
      return cached_path, true, :cached
    elseif ispath(raw_path)
      return raw_path, true, :raw
    else
      return DataFrame(), false, :none
    end  
  end

  function cache_local(id::AbstractString, f::AbstractDataFrame)
    csv_name = "$id.csv"
    cached_path = joinpath(Config.Path.dataset_cache, csv_name)
    writetable(cached_path, f)
  end

  function list(;swift=true,filesystem=true,computed=true)
    datasets = []

    # add computed datasets
    if computed
      for n in names(Build)
        if isa(getfield(Build, n), Function)
          push!(datasets, n)
        end 
      end
    end

    # add local datasets
    if filesystem
      local_listing = [readdir(Config.Path.dataset_cache); readdir(Config.Path.dataset_raw)]
      fname_matcher = r"(?i)(.+)\.csv"
      id_transform = fname -> Symbol(match(fname_matcher, fname)[1])
      local_datasets = map(id_transform, filter(fname_matcher, local_listing))

      if !isempty(local_datasets)
        push!(datasets, local_datasets...)
      end
    end

    # add swift datasets
    if swift
      object_matcher = r"(?i)(raw|processed)/(.+)\.csv"
      id_transform = obj -> Symbol(match(object_matcher, obj)[2])
      container_listing = Swift.list_objects(Config.Swift.root_container)
      swift_datasets = map(id_transform, filter(object_matcher, container_listing))
      if !isempty(swift_datasets)
        push!(datasets, swift_datasets...)
      end
    end

    unique(sort(datasets))
  end

  function search(part::AbstractString)
    r = Regex(part)
    map(Symbol, filter(r, map(string, list())))
  end

  function push(;confirm=true)
    choice = nothing

    on_swift = Dataset.list(filesystem=false,computed=false)
    on_filesystem = Dataset.list(swift=false,computed=false)
    pushlist = setdiff(on_filesystem, on_swift)

    if confirm
      println("Datasets not in $(Config.Swift.root_container)\n")
      for d in pushlist
        println(string(d))
      end
      println("\n")

      choice = ask("Push the above datasets to the $(Config.Swift.root_container) container?",
                   ["[y]es","[n]o","[s]elect"])
    else
      choice = "y"
    end

    if choice == "y"
      for d in pushlist
        push(d)
      end
    elseif choice == "n"
      println("Upload cancelled")
    elseif choice == "s"
      println("Uploading one by one\n")
      for d in pushlist
        if ask("Push $d to the $(Config.Swift.root_container) container?", ["[y]es","[n]o"]) == "y"
          push(d)
        end
      end
    end
  end

  function push(id::AbstractString)
    path, cached, source = local_path(id)
    csv_name = "$id.csv"
    prefix = (source == :cached ? Config.Swift.cache_prefix : Config.Swift.raw_prefix)
    swift_path = join([prefix, csv_name], "/")
    Swift.upload_object(Config.Swift.root_container, swift_path, filepath=path)
  end
  push(id::Symbol) = push(string(id))

  function ask(msg,options)
    choice = nothing
    pattern = r"\[(.)\](.+)"
    extract_short = x -> match(pattern, x)[1]
    extract_long = x -> match(pattern, x)[2]

    short_options = map(extract_short, options)
    long_options = map(extract_long, options)

    option_str = join(options,"/")
    long_msg = "$msg ($option_str): "
    while !(choice in short_options) && !(choice in long_options)
      print(long_msg)
      line = readline(STDIN)
      if line == ""
        break;
      end
      choice = strip(line);
    end
    long_index = findfirst(long_options, choice)
    if long_index != 0
      choice = short_options[long_index]
    end
    return choice
  end
end