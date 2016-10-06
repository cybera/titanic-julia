module CustomPlots

using Plots
using StatPlots
using DataFrames
using DataFrameUtil

@userplot FacetGridBox

@recipe function f(h::FacetGridBox; xsplit=nothing, ysplit=nothing, boxsplit=nothing)
  if length(h.args) != 2 || !(typeof(h.args[1]) <: AbstractDataFrame) || !(typeof(h.args[2]) <: Symbol)
      error("Facet Grid Boxplots should be given a DataFrame and value column.  Got: $(typeof(h.args))")
  end
  df, val = h.args

  xsplit --> xsplit
  ysplit --> ysplit
  boxsplit --> boxsplit

  delete!(d, :xsplit)
  delete!(d, :ysplit)
  delete!(d, :boxsplit)

  x = df[xsplit]
  y = df[val]

  xlevels = sort(levels(df[xsplit]))
  ylevels = sort(levels(df[ysplit]))
  boxlevels = sort(levels(df[boxsplit]))

  layout := (length(ylevels), length(xlevels))

  # set up the subplots
  legend := false
  link := :both

  seriestype := :boxplot

  xlabel := ""
  ylabel := ""

  xindex = 1
  yindex = 1
  for xlevel in xlevels
    xsubdf = subset(df, xsplit, xlevel)
    for ylevel in ylevels
      ysubdf = subset(xsubdf, ysplit, ylevel)
      boxsubdfs = map(bl -> subset(ysubdf, boxsplit, bl)[val], boxlevels)
      @series begin
        subplot := (yindex - 1) * length(xlevels) + xindex
        title := "$xlevel & $ylevel"
        ysubdf, boxsplit, val
      end
      yindex += 1
    end
    yindex = 1
    xindex += 1
  end

end

end