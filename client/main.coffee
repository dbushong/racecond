Accounts.ui.config passwordSignupFields: 'USERNAME_AND_OPTIONAL_EMAIL'

Meteor.startup ->
  Meteor.subscribe 'players'
  Meteor.autosubscribe ->
    uid = Meteor.userId() # just to create the dependency
    Meteor.subscribe 'mygames'
    Meteor.subscribe 'requests'
