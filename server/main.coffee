popRandom = (arr, num=1) ->
  res = (arr.splice(Math.random() * arr.length, 1)[0] for i in [1..num])
  if num is 1 then res[0] else res

Meteor.publish 'mygames', ->
  Games.find { players: @userId }, fields: { deck: 0 }

Meteor.publish 'myhands', ->
  Hands.find user_id: @userId

# TODO: some sort of idle detection
Meteor.publish 'players', ->
  Meteor.users.find {} , fields: { username: 1 }

Meteor.publish 'requests', ->
  Requests.find { '$or': [ { to: @userId }, { from: @userId } ] }

Meteor.methods
  startGame: (request_id) ->
    req = Requests.findOne request_id
    throw new Meteor.Error('invalid request') unless req.to is @userId

    Requests.remove request_id

    flip    = !!Math.floor(Math.random() * 2)
    players = if flip then [ req.from, req.to ] else [ req.to, req.from ]
    deck    = []
    for name, {count} of Cards
      deck.push(name) for i in [1..(count ? 1)]
    hands   = [ popRandom(deck, 4), popRandom(deck, 5) ]
    now     = new Date

    gid = Games.insert
      players:      players
      x:            0
      i:            0
      cur_player:   0
      actions_left: 2
      threads:      [ 0, null, null ]
      program:      [ 'i = 1' ]
      discard:      []
      created_at:   now
      updated_at:   now
      deck:         deck

    for uid, i in players
      Hands.insert
        user_id: uid
        game_id: gid
        cards:   hands[i]

    gid
