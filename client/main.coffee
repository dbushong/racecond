email = (uid) ->
  Meteor.users.findOne(uid).emails[0].address

Template.board.show = -> !!Session.get('game_id')

_.extend Template.lobby,
  email: email

  show: -> !Session.get('game_id')

  players: -> Meteor.users.find({ _id: { '$ne': Meteor.userId() } }).fetch()

  outBoundRequest: -> @from is Meteor.userId()

  otherPlayer: ->
    player = @players[if @players[0].uid is Meteor.userid() then 1 else 0]
    email player.uid

  requests: -> Requests.find({}).fetch()

  games: -> []

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
        Session.set 'game_id', game_id
      false
    'click a.reject-req': (e) ->
      rid = e.target.dataset.id
      console.log "reject request #{rid}"
      Requests.remove rid
      false

Meteor.startup ->
  Meteor.subscribe 'players'
  Meteor.autosubscribe ->
    uid = Meteor.userId() # just to create the dependency
    Meteor.subscribe 'mygames'
    Meteor.subscribe 'requests'
  Meteor.autosubscribe ->
    uid = Meteor.userId() # just to create the dependency
    gid = Session.get 'game_id'
    Meteor.subscribe 'game', gid if gid
