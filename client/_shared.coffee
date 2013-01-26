username = (uid) -> Meteor.users.findOne(uid).username
hand     = -> Hands.findOne(game_id: game()._id).cards
isCurrentPlayer = -> game().cur_player is Meteor.userId()
handleErr = (name, err) ->
  if err
    console.error action, err
    alert "failed to #{action}: #{err.reason}"
