Accounts.ui.config passwordSignupFields: 'USERNAME_AND_OPTIONAL_EMAIL'

Meteor.startup ->
  Meteor.subscribe 'players'
  Meteor.autosubscribe ->
    uid = Meteor.userId() # just to create the dependency
    Meteor.subscribe 'mygames'
    Meteor.subscribe 'myhands'
    Meteor.subscribe 'requests'
    Games.find({}).observe
      added: (g) ->
        console.log 'added', game(), Session.get('last_request_id'), g
        if !game() and g.request_id is Session.get('last_request_id')
          Session.set 'game_id', g._id
