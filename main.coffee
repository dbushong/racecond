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
, skip_advance: [] // which treads to skip execute/advancing at turn end
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
    assign: -> i: 1
  'i = -1':
    descr: 'FIXME'
    copies: 2
    assign: -> i: -1
  'i = -abs(i)':
    descr: 'FIXME'
    assign: (g) -> i: -Math.abs(g.i)
  'break':
    descr: 'FIXME'
    valid: (g, h, hpos, {position, indent}) ->
      return false unless validIndent g.program, {position, indent}
      # break is fine anywhere inside a while clause
      { all } = AST g.program
      !!_.find all, (entry) ->
        /^while /.test(entry.instr) and entry.pos < position and
          (entry.end_pos ? entry.pos)+1 >= position and
            (all[position-1]?.depth + indent) > entry.depth
  'else':
    descr: 'FIXME'
    indenter: true
    valid: (g, h, hpos, {position, indent}) ->
      return false unless validIndent g.program, {position, indent}
      { all } = AST g.program
      !!_.find all, (entry) ->
        # we need to be trying into insert into
        # * an "if" clause
        # * not immediately after the "if"
        # * the "if" clause can't already have an "else" after it
        # * at the same indentation as the "if" clause
        end = entry.end_pos ? entry.pos
        /^if /.test(entry.instr) and
          entry.pos + 2 <= position <= end + 1 and
          all[end + 1]?.instr isnt 'else' and
          all[end].depth + indent is entry.depth
  'ADVANCE ALL THREADS':
    descr: 'FIXME'
    actions: 1
    valid: -> true
  'DELETE CARD':
    descr: 'FIXME'
    copies: 3
    actions: 1
    args: ['instruction']
    valid: (g, h, pos, { instruction }) ->
      # FIXME: also needs to make sure you're not deleting an if/while
      # with a dependent else/break in it
      0 <= instruction < g.program.length and instruction not in g.threads
  'FAST FORWARD':
    descr: 'Advance any single NEXT pointer twice.\nIn other words, choose any NEXT card on the board, execute the instruction it points to, move it to its next instruction, execute that instruction, and move it to the next instruction after that one.'
    copies: 2
    actions: 1
    args: ['thread']
    valid: (g, h, pos, { thread }) -> thread in g.threads
  'MOVE CARD':
    descr: 'FIXME'
    copies: 3
    actions: 2
    args: ['instruction', 'position', 'indent']
    valid: (g, h, pos, { instruction, position }) ->
      # FIXME: implement validity check for move card without looping
      false
  'i = -i':
    descr: 'FIXME'
    assign: (g) -> i: -g.i
  'i = abs(i)':
    descr: 'FIXME'
    assign: (g) -> i: Math.abs(g.i)
  'i = min(i+1, 5)':
    descr: 'FIXME'
    assign: (g) -> i: Math.min(g.i+1, 5)
  'i = max(i-1, -5)':
    descr: 'FIXME'
    assign: (g) -> i: Math.max(g.i-1, 5)
  'if (i < 0)':
    descr: 'FIXME'
    copies: 2
    indenter: true
    if: (g) -> g.i < 0
  'if (i > 0)':
    descr: 'FIXME'
    copies: 2
    indenter: true
    if: (g) -> g.i > 0
  'INSERT CARD':
    descr: 'FIXME'
    copies: 3
    actions: 1
    args: ['hand_instruction', 'position', 'indent']
    valid: (g, h, pos, { hand_instruction, position }) ->
      # FIXME: also needs to validate that's an OK place to stick the card,
      # without recursively calling validPlays() on the whole hand
      (c = Cards[h[hand_instruction]]) and not c.actions? and
        0 <= position <= g.program.length
  'KILL THREAD':
    descr: 'Remove any single NEXT pointer.\nChoose any NEXT card on the board to remove.  If another NEXT pointer exists, discard the selected card.  If this is the only NEXT pointer on the board, move it to the top of the program.'
    actions: 1
    args: ['thread']
    valid: (g, h, hpos, { thread }) -> g.threads[thread]?
  'NEW HAND':
    descr: 'Draw a fresh hand.\nDiscard as many cards as desired.  Draw new cards until your hand contains 5 cards.'
    actions: 1
    args: ['hand_cards']
    valid: (g, h, pos, { hand_cards }) ->
      hand_cards.length < h.length and
        _.every hand_cards, (c) -> 0 <= c < h.length and c isnt pos
  'NEW THREAD (2)':
    descr: 'Place at any instruction.\nStarts a new thread.  Uses both actions, and the new instruction does not execute this turn.'
    actions: 2
    args: ['instruction']
    valid: (g, h, pos, { instruction }) -> 0 <= instruction < g.program.length
  'NEW THREAD (3)':
    descr: 'Place at any instruction.\nStarts a new thread.  Uses both actions, and the new instruction does not execute this turn.'
    actions: 2
    args: ['instruction']
    valid: (g, h, pos, { instruction }) -> 0 <= instruction < g.program.length
  'SET i':
    descr: 'FIXME'
    actions: 1
    args: ['set_i']
    valid: (g, h, pos, { set_i }) -> -2 <= set_i <= 2
  'SET NEXT':
    descr: "Move any single NEXT pointer to point to any instruction on the board.\nPlaying this card uses both of the player's actions, and the new instruction does not execute during the Advance Next phase of this turn."
    actions: 2
    count: 2
    args: ['thread', 'instruction']
    valid: (g, h, pos, { thread, instruction }) ->
      g.threads[thread]? and 0 <= instruction < g.program.length
  'SKIP ALL THREADS':
    descr: 'Playing this card cancels the Advance Next phase of this turn.  No NEXT pointers are executed or moved.'
    actions: 1
    valid: -> true
  'TRADE HANDS':
    descr: "Trade hands with your opponent.\nYou receive the cards that were in your opponent's hand, and your opponent receives the cards that were in your hand (not including this one)."
    actions: 1
    valid: -> true
  'while (i < 0)':
    descr: 'FIXME'
    indenter: true
    while: (g) -> g.i < 0
  'while (i > 0)':
    descr: 'FIXME'
    indenter: true
    while: (g) -> g.i > 0
  'while (i < 2)':
    descr: 'FIXME'
    indenter: true
    while: (g) -> g.i < 2
  'while (i > -2)':
    descr: 'FIXME'
    indenter: true
    while: (g) -> g.i > -2
  'x = x + i':
    descr: 'FIXME'
    count: 4
    assign: (g) -> x: g.x + g.i
  'x = x - i':
    descr: 'FIXME'
    count: 4
    assign: (g) -> x: g.x - g.i
  'x = x - 1':
    descr: 'FIXME'
    count: 2
    assign: (g) -> x: g.x - 1
  'x = x + 1':
    descr: 'FIXME'
    count: 2
    assign: (g) -> x: g.x + 1
do -> # scope card & name
  card.name = name for name, card of Cards # for convenience

game = (gid = Session.get('game_id')) -> Games.findOne gid

validIndent = (prog, { position, indent }) ->
  min_indent = max_indent = 0

  if prog.length > 0 and position > 0
    # if preceding card is indenter, we have to indent by 1
    if Cards[prog[position-1][0]].indenter
      max_indent = min_indent = 1
    # otherwise, check to see how deep we can exdent
    else
      min_indent -= shift for [card, shift] in prog[0...position]

  min_indent <= indent <= max_indent

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

powerSet = (set) ->
  return [[]] unless set.length
  s = powerSet set[1..]
  s.concat([set[0], x...] for x in s)

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
  else
    options = _.map args, (arg) ->
      switch arg
        when 'instruction' then [0...g.program.length]
        when 'thread' then (i for t, i in g.threads when t?)
        when 'position' then [0..g.program.length]
        when 'hand_instruction' then (c for c in h when !Cards[c].actions)
        when 'hand_cards'
          if h.length > 1 then powerSet(i for c,i in h when i isnt hpos) else []
        when 'set_i' then [-2..2]
        when 'indent' then [-max_depth..1]
        else throw new Meteor.Error('wtf bad arg')
    
    options = (([args[i], val] for val in opts) for opts, i in options)
    combos  = (_.object set for set in cartesianProduct(options))
    _.filter combos, (combo) ->
      if card.valid
        card.valid g, h, hpos, combo
      else # instruction!
        validIndent g.program, combo

# can remove when meteor underscore -> 1.4.4
_.findWhere ?= (obj, attrs) ->
  if _.isEmpty(attrs)
    null
  else
    _.find obj, (value) ->
      for key of attrs
        return false if attrs[key] isnt value[key]
      true
