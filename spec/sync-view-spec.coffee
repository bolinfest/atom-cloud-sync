sv = require '../lib/sync-view'
{SyncDescription, FILENAME: SYNCFILE} = require '../lib/sync-description'
path = require 'path'
fs = require 'fs'
{Directory, File} = require 'pathwatcher'

describe 'shareUriFor', ->

  it 'forms proper cloud-sync-config uris', ->
    actual = sv.shareUriFor '/some/absolute/path'
    expected = 'cloud-sync-config://some/absolute/path'
    expect(actual).toBe(expected)

describe 'registerOpenerIn', ->

  it 'registers a cloud-sync-config opener', ->
    gotit = false

    receiver =
      registerOpener: (callback) -> gotit = true

    sv.registerOpenerIn receiver
    expect(gotit).toBe(true)

describe 'SyncView', ->

  [base] = []

  fullPathFor = (relativePath...) ->
    path.join base, 'sync-view', relativePath...

  syncViewIn = (relativePath...) ->
    uri = sv.shareUriFor fullPathFor relativePath...
    new sv.SyncView(uri)

  resetFixtures = ->
    fs.unlink fullPathFor('nodesc', '.cloud-sync.json'), (err) ->

    new File(fullPathFor 'somedesc', SYNCFILE).write(
      """{
           "container": "derpderp",
           "directory": ""
         }

      """)

  beforeEach ->
    base = atom.project.getRootDirectory().getRealPathSync()
    resetFixtures()

  afterEach -> resetFixtures()

  describe 'refresh', ->

    it 'disables the Apply button until data is loaded', ->
      view = syncViewIn 'parent', 'child'
      expect(view.ready).toBe(false)
      expect(view.applyButton.prop 'disabled').toBe(true)

    it 'populates editors with existing data', ->
      view = syncViewIn 'parent', 'child'
      waitsFor -> view.ready
      runs ->
        expect(view.containerName.getText()).toBe('derpderp')
        expect(view.directoryName.getText()).toBe('snorf')
        expect(view.isPublic.prop 'checked').toBe(false)

  describe 'checkValidity', ->

    [view] = []

    beforeEach -> view = syncViewIn 'nodesc'

    it 'disallows empty container names', ->
      view.containerName.setText ''
      view.checkValidity()

      expect(view.containerInput.hasClass 'text-error').toBe(true)
      expect(view.containerErr.css 'display').toBe('block')
      messages = view.containerErr.find('span')
      expect(messages.length).toBe(1)

    it 'disallows the / character', ->
      view.containerName.setText "I'm rgbkrk / and I'm here to say
        / I like breaking stuff / every day"
      view.checkValidity()

      expect(view.containerInput.hasClass 'text-error').toBe(true)
      expect(view.containerErr.css 'display').toBe('block')
      messages = view.containerErr.find('span')
      expect(messages.length).toBe(1)

    it 'accepts anything else', ->
      view.containerName.setText 'valid'
      view.checkValidity()

      expect(view.containerInput.hasClass 'text-error').toBe(false)
      expect(view.containerErr.css 'display').toBe('none')
      messages = view.containerErr.find('span')
      expect(messages.length).toBe(0)

    describe 'with existing data', ->

      beforeEach -> view = syncViewIn 'somedesc'

      it "disables the Apply button if you haven't changed anything", ->
        view.checkValidity()
        expect(view.applyButton.prop 'disabled').toBe(true)

      it "enables the Apply button when you've made a change", ->
        view.containerName.setText 'different'
        view.checkValidity()
        expect(view.applyButton.prop 'disabled').toBe(false)

  describe 'getSyncFile', ->

    it 'uses a new .cloud-sync.json file if none exists', ->
      view = syncViewIn 'nodesc'

      waitsFor -> view.ready

      runs ->
        rp = view.getSyncFile().getRealPathSync()
        expect(rp).toBe(fullPathFor 'nodesc', SYNCFILE)

    it 'finds a .cloud-sync.json file in a parent directory', ->
      view = syncViewIn 'parent', 'child'

      waitsFor -> view.ready

      runs ->
        rp = view.getSyncFile().getRealPathSync()
        expect(rp).toBe(fullPathFor 'parent', SYNCFILE)

  describe 'apply button', ->

    it 'writes a .cloud-sync.json file', ->
      view = syncViewIn 'nodesc'
      waitsFor -> view.ready
      runs ->
        view.containerName.setText 'superawesome'
        view.directoryName.setText 'blerp'
        view.isPublic.prop 'checked', true

        view.apply()

        dir = new Directory(fullPathFor 'nodesc')
        sf = new File(fullPathFor 'nodesc', SYNCFILE)
        expect(sf.existsSync()).toBe(true)

        sd = null
        SyncDescription.createFrom sf, dir, (err, desc) ->
          console.log err if err
          sd = desc
        waitsFor -> sd?

        runs ->
          expect(sd.container).toBe('superawesome')
          expect(sd.psuedoDirectory).toBe('blerp')
          expect(sd.public).toBe(true)

  describe 'unsync button', ->

    it 'is disabled if there is no .cloud-sync.json', ->
      view = syncViewIn 'nodesc'
      waitsFor -> view.ready
      runs ->
        expect(view.unsyncButton.prop 'disabled').toBe(true)

    it 'deletes the .cloud-sync.json file', ->
      view = syncViewIn 'somedesc'
      unsynched = false

      waitsFor -> view.ready

      runs ->
        expect(view.unsyncButton.prop 'disabled').toBe(false)
        view.unsync()

      waitsFor -> view.ready

      runs ->
        fp = view.getSyncFile().getRealPathSync()
        expect(fs.existsSync fp).toBe(false)

        expect(view.unsyncButton.prop 'disabled').toBe(true)
        expect(view.applyButton.prop 'disabled').toBe(true)
        expect(view.containerName.getText()).toBe('')
        expect(view.directoryName.getText()).toBe('')
        expect(view.isPublic.prop 'checked').toBe(false)
        expect(view.containerErr.css 'display').toBe('none')

  describe 'sync button', ->

    it 'is disabled if there is no .cloud-sync.json', ->
      view = syncViewIn 'nodesc'
      waitsFor -> view.ready
      runs ->
        expect(view.syncButton.prop 'disabled').toBe(true)

    it 'uploads the directory', ->
      view = syncViewIn 'somedesc'
      waitsFor -> view.ready
      runs ->
        uploaded = false
        view.syncDescription.upload = -> uploaded = true
        view.sync()
        expect(uploaded).toBe(true)
