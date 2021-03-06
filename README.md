# titanic-julia

### Running Jupyter w/ Docker

#### Prerequisites

You'll need Docker installed from here: 

[https://www.docker.com/products/overview](https://www.docker.com/products/overview)

#### Building

From the project directory, run:

```
docker build -t cybera/julia .
```

#### Running Jupyter

From the project directory, run:

```
docker run -d -p 8888:8888 --entrypoint="/usr/local/bin/jupyter-notebook" \
-v "$PWD":/titanic-julia --name titanic-julia \
cybera/julia --ip=\* --notebook-dir=/titanic-julia
```

And go to [http://localhost:8888](http://localhost:8888) in your browser.

*Note: You don't have to give it a name (via `--name`). In this case, docker
will assign a random name that you'll have to use with any `docker stop` or 
`docker exec` commands.*

#### Command-line (for running container)

```
docker exec -it titanic-julia bash
```

#### Cleaning up

```
docker stop titanic-julia && docker rm titanic-julia
```

# Julia Framework

## Development

Use the following command to run a script with preloaded libraries/paths:

```bash
bin/run YOUR_SCRIPT
```

Use the following command to start a Julia console session with preloaded libraries/paths:

```bash
bin/console
```

When interacting with Julia in either of the above ways, global configuration will be available to you via:

```julia
Config
```

For example, `Config.Path.scripts` will return the absolute path to the "scripts" folder of your project, and `Config.Swift.root_container` will return the name of the Swift container being used to store raw and processed CSV files.

## Datasets

List available Datasets (including those stored on Swift, locally, or computable via Julia code in *src/datasets*):

```julia
Dataset.list()
```

Fetch a Dataset as a DataFrame:

```julia
Dataset.fetch(:dataset_name)
```

If the Dataset exists only in the project's Swift container, it will be downloaded and stored locally first. If the Dataset doesn't exist anywhere but is computable via code in *src/datasets*, it will be generated and then cached locally as a CSV in *data/processed*.

### Generated Datasets

Any functions referenced in files under the *src/datasets* folder are assumed to generate DataFrames. Calling `Dataset.fetch(:function_name)` will return the DataFrame generated by the function of the given `function_name` and cache it locally in your *data/processed* folder. The function needs to be exported if you want it to show up in `Dataset.list()` results, and it needs to be callable without parameters. Here's a basic example:

```julia
# src/datasets/example.jl

function helloworld()
  return DataFrame(a = [1,2], b = [3,4])
end
export helloworld 

function foo()
  return DataFrame(a = [5,6], b = [7,8])
end
export foo
```

### Searching for Datasets

As your list of raw and computed (processed) datasets grows larger, doing a `Dataset.list()` might return too many results to be useful. If you want to narrow down results when looking for existing datasets, use `Dataset.search(SEARCH_STRING)`. For example, `Dataset.search("quality")` will return a list of available datasets with *"quality"* in the name.

### Sharing Datasets

Datasets are not shared automatically, but you can share them to your project's Swift container with a simple command. Calling `Dataset.push()` will list any datasets that are in your *data/raw* or *data/processed* folder and ask whether you want to upload them all or select individual sets for upload. If you know the name of the dataset you want to upload, you can call `Dataset.push(:dataset_name)`. If you want to push all datasets that aren't already on Swift without the confirmation step (careful!!!), use `Dataset.push(confirm=false)`.

*Note*: Currently, there's no way for the `Dataset.push()` function to know whether or not a dataset that already exists in the project's swift container has changed locally. If you want others to be able to download the modified dataset, you'll have to explicitly push it, via `Dataset.push(:dataset_name)`. Those wishing to use your new dataset will also have to explicitly delete any downloaded version of it in their *data/raw* or *data/processed* folders before calling `Dataset.fetch(:dataset_name)`.       

## Groupings

The DataFrames package already allows you to group a DataFrame in a variety of ways. Consider the following simple DataFrame:

```julia
df = DataFrame(x = [0,1,2,3], y = [4,5,6,7], z = [1,2,1,2])
```

which produces:

```
4×3 DataFrames.DataFrame
│ Row │ x │ y │ z │
├─────┼───┼───┼───┤
│ 1   │ 0 │ 4 │ 1 │
│ 2   │ 1 │ 5 │ 2 │
│ 3   │ 2 │ 6 │ 1 │
│ 4   │ 3 │ 7 │ 2 │
```

All of the following will do the same transformation to group it by column *z*:

```julia
by(df, [:z], f -> DataFrame(x = mean(f[:x]), y = mean(f[:y])))

by(f -> DataFrame(x = mean(f[:x]), y = mean(f[:y])), df, [:z])

by(df, [:z]) do f
  DataFrame(x = mean(f[:x]), y = mean(f[:y]))
end

grouping_func = f -> DataFrame(x = mean(f[:x]), y = mean(f[:y]))
by(grouping_func, df, [:z])

function grouping_func2(f)
  DataFrame(x = mean(f[:x]), y = mean(f[:y]))
end
by(grouping_func2, df, [:z])
```

producing a DataFrame that looks like this:

```
2×3 DataFrames.DataFrame
│ Row │ z │ x   │ y   │
├─────┼───┼─────┼─────┤
│ 1   │ 1 │ 1.0 │ 5.0 │
│ 2   │ 2 │ 2.0 │ 6.0 │
```

Since a DataFrame may have many columns that you always want to group in a similar way, the Groupings module (under *lib/groupings.jl*) can be used to organize pre-made functions to group the columns of a particular type of DataFrame. These are nothing more than functions, used in the same way as above. Once you've added a function to group a DataFrame with particular columns to the Groupings module, via:

```julia
module Groupings

...

function your_grouping(df::AbstractDataFrame)
  DataFrame(col1 = mean(df[:col1]), col2 = mean(df[:col2]), ..., coln = mean(df[:coln]))
end

...

end
```

You can use that via:

```julia
by(Groupings.your_grouping, some_dataframe, [:some_column])
```