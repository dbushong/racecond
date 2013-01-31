username = (uid) -> Meteor.users.findOne(uid).username
hand     = -> Hands.findOne(game_id: game()._id).cards
isCurrentPlayer = -> game().cur_player is Meteor.userId()
handleErr = (name, err) ->
  if err
    console.error action, err
    alert "failed to #{action}: #{err.reason}"

orList = (arr, word='or') ->
  switch arr.length
    when 0 then ''
    when 1 then arr[0]
    when 2 then arr.join(" #{word} ")
    else "#{arr[0..-2].join(', ')}, #{word} #{arr[arr.length-1]}"

andList = (arr) -> orList arr, 'and'
