game   = -> Games.findOne(Session.get('game_id'))
player = -> if game().players[0] is Meteor.userId() then 0 else 1

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

# TODO query your hand somehow
Template.hand.cards = -> []
Template.hand.cardDescr    =
Template.program.cardDescr = (name) -> Cards[name].descr

Template.program.entries = ->
  g = game()
  for name, i in g.program
    name:    name
    descr:   Cards[name].descr
    threads: j+1 for t, j in g.threads when t is i
