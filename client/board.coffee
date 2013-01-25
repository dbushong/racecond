Template.board.show = -> !!game()
Template.board.events
  'click #back-to-lobby': ->
    Session.set('game_id', null)
    false

Template.vars.x = -> game().x
Template.vars.i = -> game().i

Template.discards.cards = -> game().discards

Template.status.goal    = -> if player() then '≥ 5' else '≤ -5'
Template.status.actions_left = -> game().actions_left
Template.status.current = ->
  g   = game()
  cur = g.players[g.cur_player]
  res = Meteor.users.findOne(cur).username
  res += ' (you)' if cur is Meteor.userId()
  res

Template.hand.cards = ->
  { name, descr: Cards[name].descr } for name in hand()
Template.hand.currentPlayer = -> isCurrentPlayer()
Template.hand.events
  'click a.play-card': (e) ->
    card = e.target.firstChild.nodeValue
    alert "playing card #{card}"
    false

Template.program.entries = ->
  g = game()
  for name, i in g.program
    {
    name
    descr:   Cards[name].descr
    threads: j+1 for t, j in g.threads when t is i
    }
