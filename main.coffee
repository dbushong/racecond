###
{ players:      [ '<uid of negative player>', '<uid of positive player>' ]
, x:            -5..5
, i:            -5..5
, cur_player:   <user id>
, winner:       null|<user id>
, actions_left: 1|2
, threads:      [ null|index-into-program, same, same ]
, program:      [ ['card_id', rel_indent], ... ]
, discard:      [ 'card_id', ... ]
, created_at:   Date
, updated_at:   Date
, finished_at:  null|Date
, deck:         [ 'card_id', ... ] // kept secret from players
, deck_count:   Number
, hand_counts:  { <uid>: Number, <uid>: Number }
, log:          [ { who: null|<uid>, what: 'msg', when: Date }, ... ]
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
  'i = min(i+1, 5)':
    descr: 'FIXME'
  'i = max(i-1, -5)':
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
    descr: "Trade hands with your opponent.\nYou receive the cards that were in your opponent's hand, and your opponent receives the cards that were in your hand (not including this one)."
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
  'x = x + i':
    descr: 'FIXME'
    count: 4
  'x = x - i':
    descr: 'FIXME'
    count: 4
  'x = x - 1':
    descr: 'FIXME'
    count: 2
  'x = x + 1':
    descr: 'FIXME'
    count: 2
card.name = name for name, card of Cards # for convenience

game = (gid = Session.get('game_id')) -> Games.findOne gid

validIndentRange = (prog, pos=prog.length) ->
  # validate position
  unless 1 <= pos <= prog.length
    throw new Meteor.Error("invalid pos specified; must be 1-#{prog.length}")

  # starting (relative) allowed indentation level
  min_indent = max_indent = 0

  if prog.length > 0
    # if preceding card is indenter, we have to indent by 1
    if Cards[prog[pos-1][0]].indenter
      max_indent = min_indent = 1
    # otherwise, check to see how deep we can exdent
    else
      min_indent -= indent for [card, indent] in prog[0..pos-1]

  [min_indent, max_indent]

AST = (prog) ->
  tree = ptr = { seq: [] }
  for [ instr, shift ] in prog
    if shift > 0 # really, 1
      ptr = ptr.seq[ptr.seq.length-1]
      ptr.seq = []
    else if shift < 0 # exdenting 
      ptr = ptr.parent for i in [shift...0]

    ptr.seq.push { instr, parent: ptr }
  tree
