username = (uid) -> Meteor.users.findOne(uid).username

_.extend Template.lobby,
  username: username

  show: -> !Session.get('game_id')

  players: -> Meteor.users.find(_id: { '$ne': Meteor.userId() }).fetch()

  outBoundRequest: -> @from is Meteor.userId()

  otherPlayer: ->
    username @players[if @players[0] is Meteor.userId() then 1 else 0]

  requests: -> Requests.find({}).fetch()

  games: -> Games.find({}).fetch()

  events:
    'click a.start-game': (e) ->
      uid = e.target.dataset.id
      console.log "request game with user #{uid}"
      if Meteor.userId()?
        Requests.insert created_at: (new Date), from: Meteor.userId(), to: uid
      else
        alert 'Please login to start a game'
      false
    'click a.cancel-req': (e) ->
      rid = e.target.dataset.id
      console.log "cancel request #{rid}"
      Requests.remove rid
      false
    'click a.accept-req': (e) ->
      rid = e.target.dataset.id
      console.log "accept request #{rid}"
      Meteor.call 'startGame', rid, (err, game_id) ->
        if err
          alert "Failed to start game: #{err.reason}"
        else
          Session.set 'game_id', game_id
      false
    'click a.reject-req': (e) ->
      rid = e.target.dataset.id
      console.log "reject request #{rid}"
      Requests.remove rid
      false
    'click a.resume-game': (e) ->
      Session.set 'game_id', e.target.dataset.id
      false
