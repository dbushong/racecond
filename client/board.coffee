game = -> Games.findOne(Session.get('game_id'))

Template.board.show = -> !!game()
Template.board.events
  'click #back-to-lobby': ->
    Session.set('game_id', null)
    false

Template.vars.x = -> game().x
Template.vars.i = -> game().i

Template.discards.cards = -> game().discards

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
