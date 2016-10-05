module DataFrameUtil
  using DataFrames, Base.Dates
  import JSON

  export subset, to_date, write_js

  function subset(df::AbstractDataFrame, column, values...)
    return df[findin(df[column],values),:]
  end

  # Subset an AbstractDataFrame based on a function. The function should take a single argument (a DataFrameRow) 
  # and output true if the row should be contained in the subset. Note that because this makes a row by row
  # comparison, it is likely not the most efficient way to subset your data.
  #
  # ex (each of the following are equivalent):
  #
  # subset(od) do row
  #   row[:city] == "Edmonton"
  # end
  #
  # subset(r -> r[:city] == "Edmonton", od)
  #
  # f = function(r)
  #   row[:city] == "Edmonton"
  # end
  # subset(f, od)
  function subset(f::Function, df::AbstractDataFrame)
    subdf = DataFrame(eltypes(df),names(df),0)
    for row in eachrow(df)
      if f(row)
        push!(subdf, convert(Array,row))
      end
    end
    return subdf
  end

  function to_dict(df::DataFrames.AbstractDataFrame)
    df_dict = Dict();
    for colname in names(df)
      df_dict[colname] = df[colname];
    end
    df_dict
  end

  function to_dict(df::DataFrames.GroupedDataFrame)
    df_dict = Dict();
    for grp in df
      r1 = grp[1,:];
      group_key = join(convert(Array, r1[df.cols]), "|");
      df_dict[group_key] = to_dict(grp);
    end
    df_dict
  end

  function write_js(filepath::AbstractString, obj, groupcols=[];
                    varname::AbstractString="dataframe", append=false)
    f = open(filepath, append ? "a" : "w");
    println(f, "var $(varname) = ", to_json(obj,groupcols), ";");
    close(f);
  end

  Base.convert(T::Type{Date}, val::UTF8String) = T(val, DateFormat("yyyy-mm-dd"))
  to_date(col::DataArrays.DataArray{UTF8String,1}) = convert(DataArrays.DataArray{Date,1}, col)

  to_json(obj,groupcols) = JSON.json(obj)
  function to_json(f::AbstractDataFrame,groupcols)
    f = !isempty(groupcols) ? groupby(f, groupcols) : f
    to_json(to_dict(f), groupcols)
  end
end