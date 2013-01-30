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

traverseAST = (prog, func) ->
  dfs = (ptr) ->
    func ptr if ptr.instr
    dfs kid for kid in (ptr.seq or [])
    null
  try dfs AST(prog)[0] catch e then e

# elses can be inserted only at the same level and immediately following a
# preceding if, as long as one doesn't already exist
validElse = (g, h, pos) ->
  traverseAST g.program, (ptr) ->
    if /^if /.test(ptr.instr)
      seq = ptr.parent.seq
      i = _.indexOf(seq, ptr)
      # if this if clause is the last clause and the pos is at the end
      if seq.length is i+1 and pos is g.program.length
        throw true


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
    valid: (g, h, pos, combo) -> # you can put a break anywhere inside a while, period
      traverseAST g.program, (ptr) ->
        if /^while /.test(ptr.instr) and ptr.end_pos >= (pos-1)
          throw true
  'else':
    descr: 'FIXME'
    indenter: true
    valid: validElse
  'advance all threads':
    descr: 'FIXME'
    actions: 1
  'delete card':
    descr: 'FIXME'
    copies: 3
    actions: 1
    args: ['instruction']
    valid: (g, h, pos, { instruction }) ->
      # FIXME: also needs to make sure you're not deleting an if/while
      # with a dependent else/break in it
      0 <= instruction < g.program.length and instruction not in g.threads
  'fast forward':
    descr: 'FIXME'
    copies: 2
    actions: 1
    args: ['thread']
    valid: (g, h, pos, { thread }) -> thread in g.threads
  'move card':
    descr: 'FIXME'
    copies: 3
    actions: 2
    args: ['instruction', 'position']
    valid: (g, h, pos, { instruction, position }) ->
      # FIXME: implement validity check for move card without looping
      false
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
    args: ['hand_instruction', 'position']
    valid: (g, h, pos, { hand_instruction, position }) ->
      # FIXME: also needs to validate that's an OK place to stick the card,
      # without recursively calling validPlays() on the whole hand
      (c = Cards[h[hand_instruction]]) and not c.actions? and
        0 <= position <= g.program.length
  'kill thread':
    descr: 'FIXME'
    actions: 1
    args: ['thread']
    valid: (g, h, pos, { thread }) -> thread in g.threads
  'new hand':
    descr: 'FIXME'
    actions: 1
    args: ['hand_cards']
    valid: (g, h, pos, { hand_cards }) ->
      _.every hand_cards, (c) -> 0 <= c < h.length and c isnt pos
  'new thread (2)':
    descr: 'FIXME'
    actions: 2
    args: ['instruction']
    valid: (g, h, pos, { instruction }) -> 0 <= instruction < g.program.length
  'new thread (3)':
    descr: 'FIXME'
    actions: 2
    args: ['instruction']
    valid: (g, h, pos, { instruction }) -> 0 <= instruction < g.program.length
  'set i':
    descr: 'FIXME'
    actions: 1
    args: ['set_i']
    valid: (g, h, pos, { set_i }) -> -2 <= set_i <= 2
  'set next':
    descr: 'FIXME'
    actions: 2
    count: 2
    args: ['thread', 'instruction']
    valid: (g, h, pos, { thread, instruction }) ->
      thread in g.threads and 0 <= instruction < g.program.length
    advance: false
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
  tree = parent = { seq: [] }
  max_depth = depth = 0

  for [ instr, shift ], pos in prog
    if shift > 0 # really, 1
      max_depth = Math.max(++depth, max_depth)
      parent = parent.seq[parent.seq.length-1]
      parent.seq = []
    else if shift < 0 # exdenting 
      depth += shift
      parent = parent.parent for i in [shift...0]

    ptr = entry = { instr, pos, parent }
    parent.seq.push entry

    # also update end_pos all the way up
    while (ptr = ptr.parent) and ptr.instr
      ptr.end_pos = pos

  [tree, max_depth]

cartesianProduct = (sets) ->
  _.reduce sets, ((mtrx, vals) ->
    _.reduce vals, ((array, val) ->
      array.concat(_.map mtrx, (row) -> row.concat([val]))
    ), []
  ), [[]]

# takes: game object, array of cards (hand) as argument, and index of card
# to review
#
# returns: array of valid plays
#
# instruction cards will each have a array with a { position: N } object
# per valid place that instruction may be inserted
#
# action cards will have a single empty object if they are playable with no
# options, and an array of objects enumerating all valid combinations of 
# options otherwise, e.g. for INSERT CARD:
# [ { hand_instruction: 2, position: 7 }
# , { hand_instruction: 2, position: 8 }
# , { hand_instruction: 3, position: 7 }
# ]
validPlays = (g, h, pos) ->
  [tree, max_depth] = AST g.program

  card = Cards[h[pos]]

  # instructions have an implicit single argument of "position"
  args = if card.actions then card.args else ['position']

  if card.actions > g.actions_left
    []
  else if args
    options = _.map args, (arg) ->
      switch arg
        when 'instruction' then [0...g.program.length]
        when 'thread' then (i for t, i in g.threads when t?)
        when 'position' then [0..g.program.length]
        when 'hand_instruction' then (c for c in h when !Cards[c].actions)
        when 'hand_cards' then (if h.length > 1 then ['ok'] else [])
        when 'set_i' then [-2..2]
        when 'indent' then [-max_depth..1]
        else throw new Meteor.Error('wtf bad arg')
    
    options = (([args[i], val] for val in opts) for opts, i in options)
    _.filter _.map(cartesianProduct(options), _.object), (combo) ->
      not card.valid or card.valid g, h, pos, combo
  else
    [{}]
