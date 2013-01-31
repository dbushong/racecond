playInstructionCard = (pos, insert=null) ->
  g = game()
  h = hand()

  plays = _.filter validPlays(g, h, pos), (play) ->
    play.position is (insert ? g.program.length)

  # shouldn't really happen
  unless plays.length
    console.error "no valid plays for hand card #{pos}"
    return

  if plays.length is 1
    play = plays[0]
  else
    indents = _.pluck(plays, 'indent')
    indents.sort (a, b) -> a - b

    # if there's actually a range to choose from, let the user pick
    indent = prompt "Select relative indent level (#{orList indents})"
    return null unless indent? and (indent = Number(indent)) in indents

    play = _.findWhere plays, { indent }

  # special mode when called from playSpecialActionCard()
  return play.indent if insert?

  Meteor.call 'playCard', g._id, pos, play, (err) ->
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
        args.hand_instruction = p-1
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

    unless _.findWhere(plays, args)
      alert 'No valid plays for those options'
      return

  if args.position?
    args.indent = playInstructionCard(args.hand_instruction, args.position)
    return unless args.indent?

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

Template.hand.haveCards = -> !!hand().length
Template.hand.cards = ->
  g = game()
  h = hand()
  for name, i in h
    card  = Cards[name]
    {
    name:     "#{if card.actions then name.toUpperCase() else name}#{if card.actions is 2 then ' -- 2 actions' else ''}"
    descr:    card.descr
    index:    i
    playable: isCurrentPlayer() and validPlays(g, h, i).length > 0
    }

Template.hand.currentPlayer = -> isCurrentPlayer()
Template.hand.canDrawCard = -> isCurrentPlayer() and hand().length < 5
Template.hand.events
  'click a.play-card': (e) ->
    pos  = e.target.dataset.index
    card = Cards[hand()[pos]]
    if card.actions
      console.log "playing special action card #{card.name}"
      playSpecialActionCard pos, card
    else
      console.log "playing instruction card #{card.name}"
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
