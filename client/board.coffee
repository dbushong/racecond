playInstructionCard = (pos) ->
  g = game()
  [min_indent, max_indent] = validIndentRange g.program
  indent = min_indent

  # if there's actually a range to choose from, let the user pick
  if min_indent isnt max_indent
    loop
      indent = Number(prompt(
        "Select relative indent level from #{min_indent} to #{max_indent}:"))
      break if indent? and min_indent <= indent <= max_indent

  Meteor.call 'playCard', g._id, pos, { indent }, (err) ->
    handleErr 'play instruction card', err

playSpecialActionCard = (pos, card) ->
  g     = game()
  h     = hand()
  args  = {}
  plays = validPlays g, h, pos

  for arg in (card.args or [])
    choices = _.uniq(_.pluck plays, arg)

    if choices.length is 1
      args[arg] = choices[0]
      continue

    switch arg
      when 'instruction'
        ns = (n+1 for n in choices)
        instr = prompt(
          "Choose an instruction # to apply this to (#{ns.join(',')}):")
        return unless instr?
        args.instruction = instr - 1
      when 'thread'
        ns = (n+1 for n in choices)
        t = prompt "Choose a thread to apply to: #{ns.join(' or ')}"
        return unless t?
        args.thread = t-1
      when 'position'
        ns = (n+1 for n in choices)
        p = prompt "Choose a position before which to place card: (#{ns.join(',')})"
        return unless p?
        args.position = p-1
      when 'hand_instruction'
        ns = (n+1 for n in choices)
        p = prompt "Choose the nth card from your hand which is an instruction: #{ns.join(' or ')}"
        return unless p?
        args.position = p-1
      when 'hand_cards'
        cs = prompt "Choose one or more card numbers from your hand to discard, separated by commas"
        return unless cs?
        args.hand_cards = (Number(n)-1 for n in cs.split(/\s*,\s*/))
      when 'set_i'
        i = prompt "Choose value to set i to (-2..2)"
        return unless i?
        args.set_i = i
      else
        throw new Meteor.Error('wtf arg')

    plays = _.filter plays, (play) ->
      _.isEqual _.pick(play, _.keys(args)...), args

    unless plays.length
      alert 'No valid plays for those options'
      return

  if args.position?
    [min_indent, max_indent] = validIndentRange g.program, args.position
    indent = min_indent

    # if there's actually a range to choose from, let the user pick
    if min_indent isnt max_indent
      args.indent = prompt(
        "Select relative indent level from #{min_indent} to #{max_indent}:")
      return unless args.indent? and min_indent <= args.indent <= max_indent

  Meteor.call 'playCard', g._id, pos, args, (err) ->
    handleErr 'play special action card', err

Template.board.show = -> !!game()
Template.board.events
  'click #back-to-lobby': ->
    Session.set('game_id', null)
    false
  'click #forfeit': ->
    if confirm('Are you sure you want to forfeit?')
      Meteor.call 'forfeit', game()._id, (err) ->
        alert("Forfeiting failed: #{err.reason}") if err
    false

Template.discards.cards = ->
  { name, descr: Cards[name].descr } for name in game().discard

_.extend Template.status,
  x: -> game().x
  i: -> game().i
  goal: -> if game().players[1] is Meteor.userId() then '≥ 5' else '≤ -5'
  actions_left: -> game().actions_left
  other_count: ->
    g = game()
    g.hand_counts[_.without(g.players, Meteor.userId())[0]]
  deck_count: -> game().deck_count
  current: ->
    uid = game().cur_player
    "#{username uid}#{if uid is Meteor.userId() then ' (you)' else ''}"

Template.hand.cards = ->
  g = game()
  h = hand()
  for name, i in h
    plays = validPlays g, h, i
    card  = Cards[name]
    {
    name:     "#{if card.actions then name.toUpperCase() else name}#{if card.actions is 2 then ' -- 2 actions' else ''}"
    descr:    card.descr
    index:    i
    playable: isCurrentPlayer() and plays.length > 0
    }

Template.hand.currentPlayer = -> isCurrentPlayer()
Template.hand.canDrawCard = -> isCurrentPlayer() and hand().length < 5
Template.hand.events
  'click a.play-card': (e) ->
    pos  = e.target.dataset.index
    card = Cards[hand()[pos]]
    if card.actions
      playSpecialActionCard pos, card
    else
      playInstructionCard pos
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
  indent = 0
  for [name, shift], i in g.program
    indent += shift
    {
    name
    descr:   Cards[name].descr
    indent:  ('&nbsp;&nbsp;' for x in [0...indent]).join('')
    threads: j+1 for t, j in g.threads when t is i
    }
