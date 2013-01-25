###
{ players:      [ '<_id of negative player>', '<... positive player>' ]
, x:            -5..5
, i:            -5..5
, cur_player:   0|1
, actions_left: 1|2
, threads:      [ null|index-into-program, same, same ]
, program:      [ 'card_id', ... ]
, discard:      [ 'card_id', ... ]
, created_at:   Date
, deck:         [ 'card_id', ... ] // kept secret from players
}
###
Games = new Meteor.Collection 'games'

###
{ game_id: <reference>
, user_id: <reference>
, cards:   [ 'card_id', ... ]
}
###
Hands = new Meteor.Collection 'hands'

###
{ from:       '<user _id>'
, to:         '<user _id>'
, created_at: Date
}
TODO: time these out
###
Requests = new Meteor.Collection 'requests'

Cards =
  'i = 1':
    descr: 'FIXME'
    copies: 0
  'i = -1':
    descr: 'FIXME'
    copies: 2
  'i = -abs(i)':
    descr: 'FIXME'
  'break':
    descr: 'FIXME'
  'else':
    descr: 'FIXME'
    indenter: true
  'advance all threads':
    descr: 'FIXME'
    actions: 1
  'delete card':
    descr: 'FIXME'
    copies: 3
    actions: 1
  'fast forward':
    descr: 'FIXME'
    copies: 2
    actions: 1
  'move card':
    descr: 'FIXME'
    copies: 3
    actions: 2
  'i = -i':
    descr: 'FIXME'
  'i = abs(i)':
    descr: 'FIXME'
  'i = min(i-1, -5)':
    descr: 'FIXME'
  'i = min(i+1, 5)':
    descr: 'FIXME'
  'if (i < 0)':
    descr: 'FIXME'
    copies: 2
    indenter: true
  'if (i > 0)':
    descr: 'FIXME'
    copies: 2
    indenter: true
  'insert card':
    descr: 'FIXME'
    copies: 3
    actions: 1
  'kill thread':
    descr: 'FIXME'
    actions: 1
  'new hand':
    descr: 'FIXME'
    actions: 1
  'new thread (2)':
    descr: 'FIXME'
    actions: 2
  'new thread (3)':
    descr: 'FIXME'
    actions: 2
  'set i':
    descr: 'FIXME'
    actions: 1
  'set next':
    descr: 'FIXME'
    actions: 2
    count: 2
  'skip all threads':
    descr: 'FIXME'
    actions: 1
  'trade hands':
    descr: 'FIXME'
    actions: 1
  'while (i < 0)':
    descr: 'FIXME'
    indenter: true
  'while (i < 0)':
    descr: 'FIXME'
    indenter: true
  'while (i < 2)':
    descr: 'FIXME'
    indenter: true
  'while (i > -2)':
    descr: 'FIXME'
    indenter: true
  'while (i > 0)':
    descr: 'FIXME'
    indenter: true

game   = -> Games.findOne Session.get('game_id')
player = -> if game().players[0] is Meteor.userId() then 0 else 1
hand   = -> Hands.findOne(game_id: game()._id).cards
isCurrentPlayer = -> game().cur_player is player()
