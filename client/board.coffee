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

playSpecialActionCard = (card, pos) ->
  alert "FIXME: special action card playing not yet implemented"

isPlayable = (card) ->
  g = game()

  return false if (card.actions or 1) > g.actions_left

  switch card.name
    when 'else', 'break'
      ptr = AST g.program
      tgt = if card.name is 'else' then /^if / else /^while /
      while ptr = ptr.seq?[ptr.seq.length-1]
        # if we're already inside an else, no can do
        return false if card.name is 'else' and ptr.instr is 'else'
        # if we found our target parent, we're good
        return true  if tgt.test ptr.instr
      # never found parent?  fail
      false
    when 'move card', 'delete card'
      # as long as there's an instruction not currently pointed to by a thread
      _.some g.program, (e,i) -> i not in g.threads
    else
      true

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
  for name, i in hand()
    card = Cards[name]
    {
    name:     "#{name}#{if card.actions is 2 then ' -- 2 actions' else ''}"
    descr:    card.descr
    index:    i
    playable: isCurrentPlayer() and isPlayable(card)
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
