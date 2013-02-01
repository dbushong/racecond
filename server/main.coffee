Meteor.publish 'mygames', ->
  Games.find { players: @userId }, fields: { deck: 0 }

Meteor.publish 'myhands', ->
  Hands.find user_id: @userId

# TODO: some sort of idle detection
Meteor.publish 'players', ->
  Meteor.users.find {} , fields: { username: 1 }

Meteor.publish 'requests', ->
  Requests.find { '$or': [ { to: @userId }, { from: @userId } ] }

verifyTurn = (g, uid) ->
  throw new Meteor.Error('not your turn') unless g.cur_player is uid

updateGame = (gid, logs, changes) ->
  console.log 'updateGame', gid, JSON.stringify(changes)
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
    assign = card.assign(g)
    _.extend set, assign
    _.extend g,   assign # for use by other threads
    what = "executed instruction: #{card.name}"
  else if card.if
    if card.if(g)
      what = 'entered if clause'
    else
      what = 'skipped if clause'
      next = (entry.end_pos ? entry.pos) + 1
  else if card.while
    if card.while(g)
      what = 'entered while loop'
    else
      what = 'skipped while loop'
      next = (entry.end_pos ? entry.pos) + 1
  else if card.name is 'break'
    what = 'broke out of while loop'
    next = whiles.shift().end_pos + 1
  else if card.name is 'else'
    prv = entry.parent.seq[_.indexOf(entry.parent.seq, entry) - 1]
    if Cards[entry.instr].if(g)
      what = 'skipped else clause'
      next = (entry.end_pos ? entry.pos) + 1
    else
      what = 'entered else clause'
  else
    throw new Meteor.Error("unmatched card type #{card.name}")

  logs.push what: "T#{thread+1}: #{what}"

  # see if we need to loop back up in a while clause
  for whl in whiles
    if next - 1 is whl.end_pos
      next = whl.pos
      break

  set["threads.#{thread}"] = g.threads[thread] = next

executeAllThreads = (g, set, logs, auto=false) ->
  for instr, thread in g.threads
    if instr? and not (auto and thread in g.skip_advance)
      executeThread g, thread, set, logs

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
          executeAllThreads(g, set, logs, true)

          who = g.players[if g.cur_player is g.players[0] then 1 else 0]
          logs.push { who, what: 'began turn' }
          _.extend set,
            actions_left: 2
            cur_player:   who
            skip_advance: []

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
      skip_advance: []
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

    verifyTurn g, @userId

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

    verifyTurn g, @userId

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

  playCard: (gid, hpos, args={}) ->
    g = game(gid)
    h = Hands.findOne(user_id: @userId, game_id: gid)

    verifyTurn g, @userId

    unless 0 <= hpos < h.cards.length
      throw new Meteor.Error("invalid hand index: #{hpos}")

    card = Cards[h.cards[hpos]]

    unless card.actions or args.position is g.program.length
      throw new Meteor.Error("invalid position for instruction card play")

    plays = validPlays g, h.cards, hpos
    unless _.isEqual(args, plays[0]) or _.findWhere(plays, args)
      throw new Meteor.Error('not a valid play')

    update = $inc: { actions_left: -(card.actions ? 1) }

    removeCard = ->
      h.cards.splice(hpos, 1)
      Hands.update h._id, $set: { cards: h.cards }
      update.$inc["hand_counts.#{@userId}"] = -1

    # if it's an instruction, let's stick it on the end
    unless card.actions
      # remove card from hand
      removeCard()

      # add card to program, decrement action count, decrement hand count
      update.$push = program: [ card.name, args.indent ]
      updateGame gid, { who: @userId, what: "added instruction: #{card.name}" },
        update

      return

    # ok, it's a special action.  switch of dooooom
    logs = [
      what: "played special action card: #{card.name}"
      who:  @userId
    ]
    discardCard = -> _.extend (update.$push ||= {}), discard: card.name

    switch card.name
      when 'TRADE HANDS'
        other_player = _.without(g.players, @userId)[0]
        other_hand   = Hands.findOne game_id: gid, user_id: other_player

        h.cards.splice(hpos, 1)
        Hands.update h._id,          $set: { cards: other_hand.cards }
        Hands.update other_hand._id, $set: { cards: h.cards          }
        # we took care of the hand; no need to do this
        removeCard = ->

        update =
          $set: _.object [
            [ "hand_counts.#{@userId}", other_hand.cards.length ]
            [ "hand_counts.#{other_player}",     h.cards.length ]
          ]
        logs.push who: @userId, what: 'traded hands'
      when 'SKIP ALL THREADS'
        update.$set = skip_advance: [0, 1, 2]
        logs.push who: @userId, what: 'will skip turn-end execution'
      when 'ADVANCE ALL THREADS'
        executeAllThreads g, (update.$set = {}), logs
      when 'FAST FORWARD'
        executeThread g, args.thread, (update.$set = {}), logs
        executeThread g, args.thread, update.$set, logs
      when 'KILL THREAD'
        # if there's only one thread left, move it to the top instead of
        # deleting
        if _.without(g.threads, null).length is 1
          what  = "moved thread #{args.thread+1} to the top"
          instr = 0
        else
          what  = "killed thread #{args.thread+1}"
          instr = null

        update.$set = {}
        update.$set["threads.#{args.thread}"] = instr
        logs.push { who: @userId, what }
      when 'NEW HAND'
        if args.hand_cards.length > 0
          hc = (Number(n) for n in args.hand_cards.split(/,/))
          logs.push
            who:  @userId
            what: "discarded #{pluralize hc.length, 'card'}"
          new_hand = []
          discard  = []
          for c, i in h.cards
            (if i is hpos or i in hc then discard else new_hand)
              .push(c)
          ndraw = 5 - new_hand.length

          logs.push
            who:  @userId
            what: "drew #{pluralize ndraw, 'card'}"

          # do we need to reshuffle already?
          if ndraw > g.deck.length
            # put what's left on the deck into our hand
            new_hand.push g.deck...
            ndraw -= g.deck.length
            # shuffle ourselves a new deck from the combined discard piles
            g.deck = _.shuffle discard.concat(g.discard)
            # mark the discard pile empty
            update.$set = discard: []
            logs.push what: 'draw pile was refreshed'
          else
            # if not, add our discards onto the discard pile
            update.$pushAll = { discard }
            update.$set     = {}

          new_hand.push g.deck.splice(0, ndraw)...
          _.extend update.$set, _.object([
            [ 'deck',                   g.deck ]
            [ "hand_counts.#{@userId}", 5      ]
          ])

          Hands.update h._id, $set: { cards: new_hand }
          removeCard = ->
          discardCard = ->
      when 'SET NEXT'
        _.extend update,
          $set: _.object [ [ "threads.#{args.thread}", args.instruction ] ]
          $push: { skip_advance: args.thread }
        logs.push
          who:  @userId
          what: "moved thread ##{args.thread+1} to position #{args.instruction+1}"
      when 'NEW THREAD (2)', 'NEW THREAD (3)'
        thread = (if card.name is 'new thread (2)' then 1 else 2)
        _.extend update,
          $set:  _.object [ [ "threads.#{thread}", args.instruction ] ]
          $push: { skip_advance: thread }
        logs.push
          who:  @userId
          what: "created #{card.name} at position #{args.instruction+1}"
      when 'SET i'
        update.$set = i: args.set_i
        logs.push who: @userId, what: "set i to #{args.set_i}"
      else
        # DELETE CARD, MOVE CARD, INSERT CARD
        throw new Meteor.Error("card #{card.name} not yet implemented")

    removeCard()
    discardCard()
    updateGame gid, logs, update unless _.isEmpty update

  advanceThread: (gid, thread) ->
    g = game(gid)

    verifyTurn g, @userId

    throw new Meteor.Error("invalid thread #{thread}") unless g.threads[thread]?

    logs = [ who: @userId, what: "advanced thread #{thread+1}" ]
    update =
      $inc: { actions_left: -1 }
      $set: {}
    executeThread g, thread, update.$set, logs
    updateGame gid, logs, update
