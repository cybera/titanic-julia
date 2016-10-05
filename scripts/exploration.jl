
using FreqTables
using Titanic

#titanic = readtable("/Users/ackerman/Desktop/Datasets/titanic.csv")
titanic = Dataset.fetch(:titanic)

freqtable(titanic[:Survived])
freqtable(titanic, :Sex, :Survived)

titanic[:Survived] = to_enum(SurvivedType, titanic[:Survived])
pool!(titanic, [:Sex, :Survived])

levels(titanic[:Survived])

using StatPlots

pie(["Female", "Male"], freqtable(titanic, :Sex))
pie(["Dead","Survived"],freqtable(titanic, :Survived))

male = titanic[titanic[:Sex] .== "male",:]
female = titanic[titanic[:Sex] .== "female",:]

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