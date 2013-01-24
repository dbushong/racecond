game = null
Meteor.startup ->
  game = -> Games.findOne(Session.get('game_id'))

Template.board.show = -> !!Session.get('game_id')

Template.vars[j] = (-> game()[j]) for j in ['x', 'i']

# TODO query your hand somehow
Template.hand.cards = -> []

Template.discards.cards = -> game().discards

Template.program.threads = -> (i + 1 for t, i in game().threads when t?)

Template.program.entries = -> game().program
