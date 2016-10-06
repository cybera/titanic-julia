# This borrows from existing R tutorials on the Titanic data set
#
#   "Kaggle R Tutorial on Machine Learning" from datacamp.com
#   Data Science Dojo
#
# The point here is to show how you can do roughly equivalent 
# operations and exploration with Julia.

using FreqTables
using Titanic

#titanic = readtable("/Users/ackerman/Desktop/Datasets/titanic.csv")
titanic = Dataset.fetch(:titanic)

freqtable(titanic[:Survived])
freqtable(titanic, :Sex, :Survived)

@enum SurvivedType Dead=0 Survived=1
titanic[:Survived] = to_enum(SurvivedType, titanic[:Survived])
pool!(titanic, [:Sex, :Survived])

levels(titanic[:Survived])
freqtable(titanic, :Sex, :Survived)

using StatPlots
pyplot()

pie(["Female", "Male"], freqtable(titanic, :Sex))
pie(["Dead", "Survived"],freqtable(titanic, :Survived))

male = titanic[titanic[:Sex] .== "male",:]
female = titanic[titanic[:Sex] .== "female",:]

# or (via framework):
male = subset(titanic, :Sex, "male")
female = subset(titanic, :Sex, "female")

layout = grid(1,2)
pie(["Dead","Survived"],freqtable(male, :Survived),title="Survival Portion of Men",layout=layout)
pie!(["Dead","Survived"],freqtable(female, :Survived),title="Survival Portion of Women",layout=layout,subplot=2)

titanic_clean = titanic
titanic_clean = titanic_clean[~isna(titanic_clean[:Age]),:]
titanic_clean = titanic_clean[~isna(titanic_clean[:Sex]),:]
titanic_clean = titanic_clean[~isna(titanic_clean[:Survived]),:]

boxplot(titanic_clean, :Sex, :Age, title="Age Distribution by Gender", notch=true)
boxplot(titanic_clean, :Survived, :Age, title="Age Distribution By Survival", notch=true, ylabel="Age")

histogram(titanic_clean[:Age], xlabel="Distribution of Age", ylabel="Frequency of Bucket", title="Distribution of Passenger Ages on Titanic",bins=12)

density(titanic_clean, :Age, groups=:Survived, linecolor=:auto, linewidth=3)
density(titanic_clean, :Age, groups=:Sex, linecolor=:auto, linewidth=3)

@enum ChildType Child=0 Adult=1

titanic[:Child] = to_enum(ChildType, map(titanic[:Age]) do x
  if isna(x)
    NA
  elseif x < 13
    Child
  else
    Adult
  end
end)

function remove_na(titanic_df, colnames...)
  ret = titanic_df;
  for colname in colnames
    ret = ret[~isna(ret[colname]),:];
  end
  ret
end

titanic_clean = remove_na(titanic, :Age, :Sex, :Survived, :Child)

import CustomPlots

CustomPlots.facetgridbox(titanic_clean, :Fare, xsplit=:Survived, ysplit=:Sex, boxsplit=:Child)