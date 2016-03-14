CocoClass = require 'core/CocoClass'
{me} = require 'core/auth'
{backboneFailure} = require 'core/errors'
storage = require 'core/storage'

# facebook user object props to
userPropsToSave =
  'first_name': 'firstName'
  'last_name': 'lastName'
  'gender': 'gender'
  'email': 'email'
  'id': 'facebookID'


module.exports = FacebookHandler = class FacebookHandler extends CocoClass
  subscriptions:
    'auth:logged-in-with-facebook': 'onFacebookLoggedIn'
    
  loadAPI: ->
    handler = @
    window.fbAsyncInit = ->
      FB.init
        appId: (if document.location.origin is 'http://localhost:3000' then '607435142676437' else '148832601965463') # App ID
        channelUrl: document.location.origin + '/channel.html' # Channel File
        status: true # check login status
        cookie: true # enable cookies to allow the server to access the session
        xfbml: true # parse XFBML
    
      Backbone.Mediator.publish 'auth:facebook-api-loaded', {}
    
      # This is fired for any auth related change, such as login, logout or session refresh.
      FB.Event.subscribe 'auth.authResponseChange', (response) ->
    
        # Here we specify what we do with the response anytime this event occurs.
        if response.status is 'connected'
    
          # They have logged in to the app.
          Backbone.Mediator.publish 'auth:logged-in-with-facebook', response: response
    
      #else if response.status is 'not_authorized'
      #  #
      #else
      #  #
    
      # Load the SDK asynchronously
      ((d) ->
        js = undefined
        id = 'facebook-jssdk'
        ref = d.getElementsByTagName('script')[0]
        return  if d.getElementById(id)
        js = d.createElement('script')
        js.id = id
        js.async = true
        js.src = '//connect.facebook.net/en_US/all.js'
    
        #js.src = '//connect.facebook.net/en_US/all/debug.js'
        ref.parentNode.insertBefore js, ref
        return
      ) document


  loggedIn: false
  
  token: -> @authResponse?.accessToken

  fakeFacebookLogin: ->
    @onFacebookLoggedIn({
      response:
        authResponse: { accessToken: '1234' }
    })

  onFacebookLoggedIn: (e) ->
    # user is logged in also when the page first loads, so check to see
    # if we really need to do the lookup
    @loggedIn = false
    @authResponse = e.response.authResponse
    for fbProp, userProp of userPropsToSave
      unless me.get(userProp)
        @loggedIn = true
        break

    @trigger 'logged-into-facebook'

  loginThroughFacebook: ->
    if @loggedIn
      return true
    else
      FB.login ((response) ->
        console.log 'Received FB login response:', response
      ), scope: 'email'

  loadPerson: ->
    FB.api '/me', {fields: 'email,last_name,first_name,gender'}, (person) =>
      attrs = {}
      for fbProp, userProp of userPropsToSave
        value = person[fbProp]
        if value
          attrs[userProp] = value
      @trigger 'person-loaded', attrs
