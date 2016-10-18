Pkg.update()

ENV["PYTHON"]=""

pkgs = ["Requests",
        "Plots",
        "StatPlots",
        "FreqTables",
        "DataFrames",
        "PyPlot",
        "DecisionTree"]

for pkg in pkgs
  Pkg.add(pkg)
end

for pkg in pkgs
  Pkg.build(pkg)
end

for pkg in pkgs
  Base.compilecache(pkg)
end

for pkg in pkgs
  eval(parse("using $pkg"))
end
