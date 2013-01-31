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
    valid: (g, h, hpos, {position, indent}) ->
      # break is fine anywhere inside a while clause
      { all } = AST g.program
      !!_.find all, (entry) ->
        /^while /.test(entry.instr) and entry.end_pos+1 >= position and
          (all[position-1].depth + indent) > entry.depth
  'else':
    descr: 'FIXME'
    indenter: true
    valid: (g, h, hpos, {position, indent}) ->
      # else is fine immediately after (at same level) as if
      { all } = AST g.program
      !!_.find all, (entry) ->
        if /^if /.test(entry.instr) and entry.seq
          if (next = entry.parent.seq[_.indexOf(entry.parent.seq, entry) + 1])
            next.position is position and next.instr isnt 'else'
          else
            position is all.length
  'advance all threads':
    descr: 'FIXME'
    actions: 1
    valid: -> true
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
    args: ['instruction', 'position', 'indent']
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
    args: ['hand_instruction', 'position', 'indent']
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
    valid: -> true
  'trade hands':
    descr: "Trade hands with your opponent.\nYou receive the cards that were in your opponent's hand, and your opponent receives the cards that were in your hand (not including this one)."
    actions: 1
    valid: -> true
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
  unless 0 <= pos <= prog.length
    throw new Meteor.Error('invalid pos specified')

  # starting (relative) allowed indentation level
  min_indent = max_indent = 0

  if prog.length > 0 and pos > 0
    # if preceding card is indenter, we have to indent by 1
    if Cards[prog[pos-1][0]].indenter
      max_indent = min_indent = 1
    # otherwise, check to see how deep we can exdent
    else
      min_indent -= indent for [card, indent] in prog[0...pos]

  [min_indent..max_indent]

AST = (prog) ->
  parent = { seq: [] }
  max_depth = depth = 0

  all =
    for [ instr, shift ], pos in prog
      if shift > 0 # really, 1
        max_depth = Math.max(++depth, max_depth)
        parent = parent.seq[parent.seq.length-1]
        parent.seq = []
      else if shift < 0 # exdenting 
        depth += shift
        parent = parent.parent for i in [shift...0]

      ptr = entry = { instr, pos, parent, depth }
      parent.seq.push entry

      # also update end_pos all the way up
      while (ptr = ptr.parent) and ptr.instr
        ptr.end_pos = pos

      entry

  { all, max_depth }

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
validPlays = (g, h, hpos) ->
  { max_depth } = AST(g.program)

  card = Cards[h[hpos]]

  # instructions have an implicit args set of "position" and "indent"
  args = if card.actions then card.args else ['position', 'indent']

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
    combos  = (_.object set for set in cartesianProduct(options))
    _.filter combos, (combo) ->
      if card.valid
        card.valid g, h, hpos, combo
      else # instruction!
        combo.indent in validIndentRange(g.program, combo.position)
  else
    [{}]

# can remove when meteor underscore -> 1.4.4
_.findWhere ?= (obj, attrs) ->
  if _.isEmpty(attrs)
    null
  else
    _.find obj, (value) ->
      for key of attrs
        return false if attrs[key] isnt value[key]
      true
