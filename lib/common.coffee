pluralize = (num, singular) ->
  "#{num ? 0} " +
    if num is 1
      singular
    else if /s$/.test singular
      singular + 'es'
    else
      singular + 's'
