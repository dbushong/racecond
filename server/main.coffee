Meteor.publish 'mygames', ->
  Games.find { players: @userId }, fields: { deck: 0 }

Meteor.publish 'myhands', ->
  Hands.find user_id: @userId

# TODO: some sort of idle detection
Meteor.publish 'players', ->
  Meteor.users.find {} , fields: { username: 1 }

Meteor.publish 'requests', ->
  Requests.find { '$or': [ { to: @userId }, { from: @userId } ] }

updateGame = (gid, logs, changes) ->
  now = new Date
  (changes.$pushAll ||= {}).log =
    _.extend log, when: now for log in _.flatten([logs]) when log.what?
  (changes.$set ||= {}).updated_at = now
  Games.update gid, changes

executeThread = (g, thread, set, logs) ->
  instr = g.threads[thread]
  return if instr >= g.program.length

  next   = instr + 1
  {all}  = AST g.program
  entry  = ptr = all[instr]
  card   = Cards[entry.instr]
  whiles = []

  # find closest containing while instruction
  while ptr = ptr.parent
    whiles.push ptr if /^while /.test ptr.instr

  if card.assign
    _.extend set, card.assign(g)
    logs.push what: "executed instruction: #{card.name}"
  else if card.if
    if card.if(g)
      logs.push what: 'entered if clause'
    else
      logs.push what: 'skipped if clause'
      next = (entry.end_pos ? entry.pos) + 1
  else if card.while
    if card.while(g)
      logs.push what: 'entered while loop'
    else
      logs.push what: 'skipped while loop'
      next = (entry.end_pos ? entry.pos) + 1
  else if card.name is 'break'
    logs.push what: 'broke out of while loop'
    next = whiles.shift().end_pos + 1
  else if card.name is 'else'
    prv = entry.parent.seq[_.indexOf(entry.parent.seq, entry) - 1]
    if Cards[entry.instr].if(g)
      logs.push what: 'skipped else clause'
      next = (entry.end_pos ? entry.pos) + 1
    else
      logs.push what: 'entered else clause'
  else
    throw new Meteor.Error("unmatched card type #{card.name}")

  # see if we need to loop back up in a while clause
  for whl in whiles
    if next - 1 is whl.end_pos
      next = whl.pos
      break

  set["threads.#{thread}"] = next

executeAllThreads = (g, set, logs) ->
  for instr, thread in g.threads
    executeThread g, thread, set, logs if instr?

Meteor.startup ->
  # game logic triggered events
  o = Games.find(finished_at: null).observe
    changed: (g, i, old) ->
      now  = new Date
      set  = {}
      logs = []

      # can we stop watching now?
      if g.finished_at?
        o.stop()
        return

      # is the game over? 
      if Math.abs(g.x) >= 5
        logs.push
          who:  (who = g.players[if g.x > 0 then 1 else 0])
          what: "won the game with x = #{g.x}"
        _.extend set, finished_at: now, winner: who, cur_player: null

      # game not over
      else
        # is the draw pile empty?
        if g.deck.length is 0 and old.deck.length > 0
          # TODO: end game in this case or something?
          if g.discard.length is 0
            throw new Meteor.Error('empty deck and discard!')

          logs.push what: 'draw pile was refreshed'
          _.extend set,
            deck:       _.shuffle(g.discard)
            discard:    []
            deck_count: g.discard.length

        # is the player's turn over?
        if g.actions_left is 0
          executeAllThreads(g, set, logs)

          who = g.players[if g.cur_player is g.players[0] then 1 else 0]
          logs.push { who, what: 'began turn' }
          _.extend set, actions_left: 2, cur_player: who

      unless _.isEmpty set
        updateGame g._id, logs, $set: set

Meteor.methods
  startGame: (request_id) ->
    req = Requests.findOne request_id
    throw new Meteor.Error('invalid request') unless req.to is @userId

    Requests.remove request_id

    flip    = !!Math.floor(Math.random() * 2)
    players = if flip then [ req.from, req.to ] else [ req.to, req.from ]
    deck    = []
    (deck.push(name) for i in [1..(count ? 1)]) for name, {count} of Cards
    deck    = _.shuffle deck
    hands   = [4, 5].map (n) -> deck.splice(0, n)
    hcounts = {}
    hcounts[players[0]] = 4
    hcounts[players[1]] = 5
    now     = new Date

    gid = Games.insert
      players:      players
      x:            0
      i:            0
      cur_player:   players[0]
      actions_left: 2
      threads:      [ 0, null, null ]
      program:      [ ['i = 1', 0] ]
      discard:      []
      created_at:   now
      updated_at:   now
      deck:         deck
      deck_count:   deck.length
      hand_counts:  hcounts
      request_id:   request_id
      log:          [
        { when: now, who: null,       what: 'game started'           }
        { when: now, who: players[0], what: 'became negative player' }
        { when: now, who: players[1], what: 'became positive player' }
        { when: now, who: players[0], what: 'began turn'             }
      ]

    for uid, i in players
      Hands.insert
        user_id: uid
        game_id: gid
        cards:   hands[i]

    gid

  drawCard: (gid) ->
    g = game(gid)
    h = Hands.findOne(user_id: @userId, game_id: gid)

    # TODO: DRY
    if g.cur_player isnt @userId
      throw new Meteor.Error('not your turn')

    if h.cards.length > 4
      throw new Meteor.Error('your hand is full')

    # remove card from deck and decrement actions
    updateGame gid, { who: @userId, what: 'drew a card' },
      $pop: { deck: -1 }
      $inc: _.object [
        [ 'actions_left',          -1 ]
        [ 'deck_count',            -1 ]
        [ "hand_counts.#{@userId}", 1 ]
      ]

    # add card to hand
    Hands.update h._id, $push: { cards: g.deck[0] }

  discardCard: (gid, i) ->
    g = game(gid)
    h = Hands.findOne(user_id: @userId, game_id: gid)

    # TODO: DRY
    if g.cur_player isnt @userId
      throw new Meteor.Error('not your turn')

    if i < 0 or i >= h.cards.length
      throw new Meteor.Error("invalid hand index: #{i}")

    # remove card from hand
    card = h.cards.splice(i, 1)[0]
    Hands.update h._id, $set: { cards: h.cards }

    # add card to discard pile and decrement actions
    updateGame gid, { who: @userId, what: "discarded card: #{card}" },
      $push: { discard: card }
      $inc:  _.object [
        [ 'actions_left',           -1 ]
        [ "hand_counts.#{@userId}", -1 ]
      ]

  forfeit: (gid) ->
    g = game(gid)

    unless @userId in g.players
      throw new Meteor.Error('you are not a player in this game')

    if g.finished_at
      throw new Meteor.Error('game is already over')

    updateGame gid, { who: @userId, what: 'forfeited the game' },
      $set:
        finished_at: (new Date)
        winner:      _.without(g.players, @userId)[0]
        cur_player:  null

  playCard: (gid, i, args={}) ->
    g = game(gid)
    h = Hands.findOne(user_id: @userId, game_id: gid)

    # TODO: DRY
    if g.cur_player isnt @userId
      throw new Meteor.Error('not your turn')

    unless 0 <= i < h.cards.length
      throw new Meteor.Error("invalid hand index: #{i}")

    plays = validPlays g, h.cards, i
    unless _.isEqual(args, plays[0]) or _.findWhere(plays, args)
      throw new Meteor.Error('not a valid play')

    card = Cards[h.cards.splice(i, 1)[0]]
    removeCard = -> Hands.update h._id, $set: { cards: h.cards }

    # if it's an instruction, let's stick it on the end
    unless card.actions
      # remove card from hand
      removeCard()

      # add card to program, decrement action count, decrement hand count
      updateGame gid, { who: @userId, what: "added instruction: #{card.name}" },
        $push: { program: [ card.name, args.indent ] }
        $inc:  _.object [
          [ 'actions_left',           -1 ]
          [ "hand_counts.#{@userId}", -1 ]
        ]

      return

    # ok, it's a special action.  switch of dooooom
    update = {}
    logs   = []
    switch card.name
      when 'trade hands'
        other_player = _.without(g.players, @userId)[0]
        other_hand   = Hands.findOne game_id: gid, user_id: other_player

        Hands.update h._id,          $set: { cards: other_hand.cards }
        Hands.update other_hand._id, $set: { cards: h.cards          }

        update =
          $set: _.object [
            [ "hand_counts.#{@userId}", other_hand.cards.length ]
            [ "hand_counts.#{other_player}",     h.cards.length ]
          ]
        
        logs.push who: @userId, what: 'traded hands'
      else
        throw new Meteor.Error("card #{card.name} not yet implemented")
        removeCard()

    updateGame gid, logs, update unless _.isEmpty update
