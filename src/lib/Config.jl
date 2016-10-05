module Config
  module Path
    root = normpath(joinpath(dirname(@__FILE__), "..", ".."))
    lib = joinpath(root, "src", "lib")
    scripts = joinpath(root, "scripts")
    config = joinpath(root, "src", "config")
    dataset_generators = joinpath(root, "src", "datasets")
    dataset_cache = joinpath(root, "data", "processed")
    dataset_raw = joinpath(root, "data", "raw")
    results = joinpath(root, "results")
  end

  module Swift
    root_container = "default"
    raw_prefix = "raw"
    cache_prefix = "processed"
  end
end

if !(Config.Path.lib in LOAD_PATH)
  push!(LOAD_PATH, Config.Path.lib)
end

for fname in readdir(Config.Path.config)
  include(joinpath(Config.Path.config, fname))
end

using DataFrames
using Plots
using Base.Dates
using DataFrameUtil

import Dataset
import Groupings