function titanic_clean()
  titanic_clean = Dataset.fetch(:titanic)

  # Replace Age NA values
  age_mean = mean(titanic_clean[:Age],skipna=true)
  titanic_clean[isna(titanic_clean[:Age]), :Age] = age_mean

  # Replace Embarked NA values
  embarked_mode = mode(dropna(titanic_clean[:Embarked]))
  titanic_clean[isna(titanic_clean[:Embarked]),:Embarked] = embarked_mode

  titanic_clean
end

export titanic_clean
