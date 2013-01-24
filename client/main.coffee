Accounts.ui.config passwordSignupFields: 'USERNAME_ONLY'

Meteor.startup ->
  Meteor.subscribe 'players'
  Meteor.autosubscribe ->
    uid = Meteor.userId() # just to create the dependency
    Meteor.subscribe 'mygames'
    Meteor.subscribe 'requests'
  Meteor.autosubscribe ->
    uid = Meteor.userId() # just to create the dependency
    gid = Session.get 'game_id'
    Meteor.subscribe 'game', gid if gid
