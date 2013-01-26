Template.board.show = -> !!game()
Template.board.events
  'click #back-to-lobby': ->
    Session.set('game_id', null)
    false
  'click #forfeit': ->
    if confirm('Are you sure you want to forfeit?')
      Meteor.call 'forfeit', game()._id, (err) ->
        alert("Forfeiting failed: #{err.reason}") if err
    false

Template.discards.cards = ->
  { name, descr: Cards[name].descr } for name in game().discard

_.extend Template.status,
  x: -> game().x
  i: -> game().i
  goal: -> if game().players[1] is Meteor.userId() then '≥ 5' else '≤ -5'
  actions_left: -> game().actions_left
  other_count: ->
    g = game()
    g.hand_counts[_.without(g.players, Meteor.userId())[0]]
  deck_count: -> game().deck_count
  current: ->
    uid = game().cur_player
    "#{username uid}#{if uid is Meteor.userId() then ' (you)' else ''}"

Template.hand.cards = ->
  for name, i in hand()
    card = Cards[name]
    {
    name:     "#{name}#{if card.actions is 2 then ' -- 2 actions' else ''}"
    descr:    card.descr
    index:    i
    playable: isCurrentPlayer() and (card.actions or 1) <= game().actions_left
    }
Template.hand.currentPlayer = -> isCurrentPlayer()
Template.hand.canDrawCard = -> isCurrentPlayer() and hand().length < 5
Template.hand.events
  'click a.play-card': (e) ->
    i = e.target.dataset.index
    Meteor.call 'playCard', game()._id, i, (err) ->
      alert "failed to play card: #{err.reason}" if err
    false
  'click a.discard-card': (e) ->
    i = e.target.dataset.index
    console.log "discarding card: #{hand()[i]}"
    Meteor.call 'discardCard', game()._id, i, (err) ->
      alert "failed to discard card: #{err.reason}" if err
    false
  'click a#draw-card': ->
    console.log 'drawing a card'
    Meteor.call 'drawCard', game()._id, (err) ->
      alert "failed to draw a card: #{err.reason}" if err
    false

Template.log.entries = ->
  for entry in game().log
    "#{entry.when}#{if entry.who? then " #{username entry.who}" else ''} #{entry.what}"

Template.program.entries = ->
  g = game()
  for [name, indent], i in g.program
    {
    name
    descr:   Cards[name].descr
    indent:  ('&nbsp;&nbsp;' for i in [0...indent]).join('')
    threads: j+1 for t, j in g.threads when t is i
    }
