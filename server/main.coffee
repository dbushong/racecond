Meteor.publish 'mygames', ->
  Games.find { 'players.uid': @userId }, fields: { players: 1 }

# TODO: some sort of idle detection
Meteor.publish 'players', ->
  Meteor.users.find {} , fields: { emails: 1 }

Meteor.publish 'requests', ->
  Requests.find { '$or': [ { to: @userId }, { from: @userId } ] }
