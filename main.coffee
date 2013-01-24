###
{ players:      [ '<_id of negative player>', '<... positive player>' ]
, x:            -5..5
, i:            -5..5
, cur_player:   0|1
, actions_left: 1|2
, threads:      [ null|index-into-program, same, same ]
, program:      [ 'card_id', ... ]
, discard:      [ 'card_id', ... ]
, secret:       { deck:  [ 'card_id', ... ]
                , hands: [ [ 'card_id', ... ], [ 'card_id', ... ] ]
                }
}
###
Games = new Meteor.Collection 'games'

###
{ from:       '<user _id>'
, to:         '<user _id>'
, created_at: Date
}
TODO: time these out
###
Requests = new Meteor.Collection 'requests'
