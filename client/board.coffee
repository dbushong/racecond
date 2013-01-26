Template.board.show = -> !!game()
Template.board.events
  'click #back-to-lobby': ->
    Session.set('game_id', null)
    false

Template.discards.cards = -> game().discards

Template.status.x = -> game().x
Template.status.i = -> game().i
Template.status.goal = ->
  if game().players[1] is Meteor.userId() then '≥ 5' else '≤ -5'
Template.status.actions_left = -> game().actions_left
Template.status.current = ->
  g   = game()
  res = username(g.cur_player)
  res += ' (you)' if g.cur_player is Meteor.userId()
  res

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
    alert "(not really) playing card: #{hand()[i]}"
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
  for name, i in g.program
    {
    name
    descr:   Cards[name].descr
    threads: j+1 for t, j in g.threads when t is i
    }
