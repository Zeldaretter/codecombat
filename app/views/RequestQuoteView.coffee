RootView = require 'views/core/RootView'
forms = require 'core/forms'
TrialRequest = require 'models/TrialRequest'
TrialRequests = require 'collections/TrialRequests'
AuthModal = require 'views/core/AuthModal'
storage = require 'core/storage'
errors = require 'core/errors'
ConfirmModal = require 'views/editor/modal/ConfirmModal'

FORM_KEY = 'request-quote-form'

module.exports = class RequestQuoteView extends RootView
  id: 'request-quote-view'
  template: require 'templates/request-quote-view'
  logoutRedirectURL: null

  events:
    'change #request-form': 'onChangeRequestForm'
    'submit #request-form': 'onSubmitRequestForm'
    'click #email-exists-login-link': 'onClickEmailExistsLoginLink'
    'submit #signup-form': 'onSubmitSignupForm'
    'click #logout-link': -> me.logout()

  initialize: ->
    @trialRequest = new TrialRequest()
    @trialRequests = new TrialRequests()
    @trialRequests.fetchOwn()
    @supermodel.trackCollection(@trialRequests)

  onLoaded: ->
    if @trialRequests.size()
      @trialRequest = @trialRequests.first()
    if @trialRequest and @trialRequest.get('status') isnt 'submitted' and @trialRequest.get('status') isnt 'approved'
      window.tracker?.trackEvent 'View Trial Request', category: 'Teachers', label: 'View Trial Request', ['Mixpanel']
    super()
    
  afterRender: ->
    super()
    
    # apply existing trial request on form
    properties = @trialRequest.get('properties')
    if properties
      forms.objectToForm(@$('#request-form'), properties)
      commonLevels = _.map @$('[name="educationLevel"]'), (el) -> $(el).val()
      submittedLevels = properties.educationLevel or []
      otherLevel = _.first(_.difference(submittedLevels, commonLevels)) or ''
      @$('#other-education-level-checkbox').attr('checked', !!otherLevel)
      @$('#other-education-level-input').val(otherLevel)
      
    # apply changes from local storage
    obj = storage.load(FORM_KEY)
    if obj
      @$('#other-education-level-checkbox').attr('checked', obj.otherChecked)
      @$('#other-education-level-input').val(obj.otherInput)
      forms.objectToForm(@$('#request-form'), obj, { overwriteExisting: true })

  onChangeRequestForm: ->
    # save changes to local storage
    obj = forms.formToObject(@$('form'))
    obj.otherChecked = @$('#other-education-level-checkbox').is(':checked')
    obj.otherInput = @$('#other-education-level-input').val()
    storage.save(FORM_KEY, obj, 10)

  onSubmitRequestForm: (e) ->
    e.preventDefault()
    form = @$('#request-form')
    attrs = forms.formToObject(form)
    
    # custom other input logic (also used in form local storage save/restore)
    if @$('#other-education-level-checkbox').is(':checked')
      attrs.educationLevel.push(@$('#other-education-level-input').val())
      
    forms.clearFormAlerts(form)
    requestFormSchema = if me.isAnonymous() then requestFormSchemaAnonymous else requestFormSchemaLoggedIn
    result = tv4.validateMultiple(attrs, requestFormSchemaAnonymous)
    error = false
    if not result.valid
      forms.applyErrorsToForm(form, result.errors)
      error = true
    if not forms.validateEmail(attrs.email)
      forms.setErrorToProperty(form, 'email', 'Invalid email.')
      error = true
    if not _.size(attrs.educationLevel)
      forms.setErrorToProperty(form, 'educationLevel', 'Check at least one.')
      error = true
    if error
      forms.scrollToFirstError()
      return
    @trialRequest = new TrialRequest({
      type: 'course'
      properties: attrs
    })
    if me.get('role') is 'student' and not me.isAnonymous()
      modal = new ConfirmModal({
        title: ''
        body: "<p>#{$.i18n.t('teachers_quote.conversion_warning')}</p><p>#{$.i18n.t('teachers_quote.learn_more_modal')}</p>"
        confirm: $.i18n.t('common.continue')
        decline: $.i18n.t('common.cancel')
      })
      @openModalView(modal)
      modal.once 'confirm', @saveTrialRequest, @
    else
      @saveTrialRequest()
    
  saveTrialRequest: ->
    @trialRequest.notyErrors = false
    @$('#submit-request-btn').text('Sending').attr('disabled', true)
    @trialRequest.save()
    @trialRequest.on 'sync', @onTrialRequestSubmit, @
    @trialRequest.on 'error', @onTrialRequestError, @
    me.setRole @trialRequest.get('properties').role.toLowerCase(), true

  onTrialRequestError: (model, jqxhr) ->
    @$('#submit-request-btn').text('Submit').attr('disabled', false)
    if jqxhr.status is 409
      userExists = $.i18n.t('teachers_quote.email_exists')
      logIn = $.i18n.t('login.log_in')
      @$('#email-form-group')
        .addClass('has-error')
        .append($("<div class='help-block error-help-block'>#{userExists} <a id='email-exists-login-link'>#{logIn}</a>"))
      forms.scrollToFirstError()
    else 
      errors.showNotyNetworkError(arguments...)

  onClickEmailExistsLoginLink: ->
    modal = new AuthModal({ initialValues: { email: @trialRequest.get('properties')?.email } })
    @openModalView(modal)

  onTrialRequestSubmit: ->
    storage.remove(FORM_KEY)
    @$('#request-form, #form-submit-success').toggleClass('hide')
    window.tracker?.trackEvent 'Submit Trial Request', category: 'Teachers', label: 'Trial Request', ['Mixpanel']

  onSubmitSignupForm: (e) ->
    e.preventDefault()
    form = @$('#signup-form')
    attrs = forms.formToObject(form)

    forms.clearFormAlerts(form)
    result = tv4.validateMultiple(attrs, signupFormSchema)
    if not result.valid
      return forms.applyErrorsToForm(form, result.errors)
    if attrs.password1 isnt attrs.password2
      return forms.setErrorToProperty(form, 'password1', 'Passwords do not match')
    
    console.log 'submit attrs', attrs
    # TODO: Create user account



requestFormSchemaAnonymous = {
  type: 'object'
  required: ['firstName', 'lastName', 'email', 'organization', 'role', 'numStudents']
  properties:
    firstName: { type: 'string' }
    lastName: { type: 'string' }
    name: { type: 'string', minLength: 1 }
    email: { type: 'string', format: 'email' }
    phoneNumber: { type: 'string' }
    role: { type: 'string' }
    organization: { type: 'string' }
    city: { type: 'string' }
    state: { type: 'string' }
    country: { type: 'string' }
    numStudents: { type: 'string' }
    educationLevel: {
      type: 'array'
      items: { type: 'string' }
    }
    notes: { type: 'string' }
}

# same form, but add username input
requestFormSchemaLoggedIn = _.cloneDeep(requestFormSchemaAnonymous)
requestFormSchemaLoggedIn.required.push('name')

signupFormSchema = {
  type: 'object'
  required: ['name', 'password1', 'password2']
  properties:
    name: { type: 'string' }
    password1: { type: 'string' }
    password2: { type: 'string' }
}
