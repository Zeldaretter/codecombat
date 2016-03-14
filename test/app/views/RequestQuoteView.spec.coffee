RequestQuoteView = require 'views/RequestQuoteView'
storage = require 'core/storage'
forms = require 'core/forms'

describe 'RequestQuoteView', ->
  
  view = null
  
  successFormValues = {
    firstName: 'A'
    lastName: 'B'
    email: 'C@D.com'
    phoneNumber: '555-555-5555'
    role: 'Teacher'
    organization: 'School'
    city: 'Springfield'
    state: 'AA'
    country: 'asdf'
    numStudents: '1-10'
    educationLevel: ['Middle']
  }
  
  describe 'when user is anonymous and has no role', ->
    beforeEach (done) ->
      me.unset('role')
      spyOn(me, 'isAnonymous').and.returnValue(true)
      view = new RequestQuoteView()
      view.render()
      jasmine.demoEl(view.$el)
  
      spyOn(storage, 'load').and.returnValue({ lastName: 'Saved Changes' })
  
      request = jasmine.Ajax.requests.mostRecent()
      request.respondWith({
        status: 200
        responseText: JSON.stringify([{
          _id: '1'
          properties: {
            firstName: 'First'
            lastName: 'Last'
          }
        }])
      })
      _.defer done # Let SuperModel finish

    describe 'after loading user\'s existing requests', ->
      
      it 'shows data from the most recent request', ->
        expect(view.$('input[name="firstName"]').val()).toBe('First')
      
      it 'prioritizes showing local, unsaved changes', ->
        expect(view.$('input[name="lastName"]').val()).toBe('Saved Changes')
      
    describe 'when the form changes', ->
      
      it 'stores local, unsaved changes', ->
        spyOn(storage, 'save')
        view.$('input[name="firstName"]').val('Just Changed').change()
        expect(storage.save).toHaveBeenCalled()
        args = storage.save.calls.argsFor(0)
        expect(args[1].firstName).toBe('Just Changed')
      
    describe 'on successful form submit', ->
      beforeEach ->
        forms.objectToForm(view.$el, successFormValues)
        view.$('#request-form').submit()
        @submitRequest = _.last(jasmine.Ajax.requests.filter((r) -> _.string.startsWith(r.url, '/db/trial.request')))
        @submitRequest.respondWith({
          status: 201
          responseText: JSON.stringify(_.extend({_id: 'a'}, successFormValues))
        })
      
      it 'creates a new trial request', ->
        expect(@submitRequest).toBeTruthy()
        expect(@submitRequest.method).toBe('POST')
  
      it 'sets the user\'s role to the one they chose', ->
        request = _.last(jasmine.Ajax.requests.filter((r) -> _.string.startsWith(r.url, '/db/user')))
        expect(request).toBeTruthy()
        expect(request.method).toBe('PUT')
        expect(JSON.parse(request.params).role).toBe('teacher')
      
      it 'shows a signup form', ->
        expect(view.$('#signup-form').hasClass('hide')).toBe(false)
      
    describe 'when an anonymous user tries to submit a request with an existing user\'s email', ->
  
      beforeEach ->
        forms.objectToForm(view.$el, successFormValues)
        view.$('#request-form').submit()
        @submitRequest = _.last(jasmine.Ajax.requests.filter((r) -> _.string.startsWith(r.url, '/db/trial.request')))
        @submitRequest.respondWith({
          status: 409
          responseText: '{}'
        })
  
      it 'shows an error that the email already exists', ->
        expect(view.$('#email-form-group').hasClass('has-error')).toBe(true)
        expect(view.$('#email-form-group .error-help-block').length).toBe(1)
      
  describe 'when user is a student and not anonymous', ->
    beforeEach (done) ->
      me.set('role', 'student')
      me.set('name', 'Some User')
      spyOn(me, 'isAnonymous').and.returnValue(false)
      view = new RequestQuoteView()
      view.render()
      jasmine.demoEl(view.$el)

      request = jasmine.Ajax.requests.mostRecent()
      request.respondWith({ status: 200, responseText: '[]'})
      _.defer done # Let SuperModel finish
    
    it 'shows a conversion warning', ->
      expect(view.$('#conversion-warning').length).toBe(1)
      
    it 'requires confirmation to submit the form', ->
      
      