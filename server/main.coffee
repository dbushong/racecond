Meteor.publish 'mygames', ->
  Games.find { 'players.uid': @userId }, fields: { players: 1 }

Meteor.publish 'game', (gid) ->
  games = Games.find(gid)
  throw new Meteor.Error('invalid game id') unless @userId in games[0].players
  games

# TODO: some sort of idle detection
Meteor.publish 'players', ->
  Meteor.users.find {} , fields: { emails: 1 }

Meteor.publish 'requests', ->
  Requests.find { '$or': [ { to: @userId }, { from: @userId } ] }

Meteor.methods
  startGame: (request_id) ->
    req = Requests.findOne request_id
    throw new Meteor.Error('invalid request') unless req.to is @userId
    Requests.remove request_id
    # TODO: start game here using req.from and req.to
    gid = null
    gid
