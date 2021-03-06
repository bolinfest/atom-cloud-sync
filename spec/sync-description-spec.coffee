{SyncDescription} = require '../lib/sync-description'
{Directory, File} = require 'pathwatcher'
path = require 'path'

describe 'SyncDescription', ->

  fixtureDir = (names...) ->
    root = atom.project.getRootDirectory()
    dirname = path.join root.getRealPathSync(), 'sync-description', names...
    new Directory(dirname)

  fixturePath = (names...) -> fixtureDir(names...).getRealPathSync()

  withDescription = (subpath, callback) ->
    root = fixtureDir().getRealPathSync()
    d = new Directory fixturePath subpath[..-2]...
    f = new File fixturePath subpath...

    sd = null
    SyncDescription.createFrom f, d, (err, instance) ->
      if err
        console.log err
        callback(null)
      sd = instance

    waitsFor -> sd?
    runs -> callback(sd)

  it 'finds all .cloud-sync.json files in the project', ->
    dirs = []

    SyncDescription.findAllIn fixtureDir(), (err, desc) ->
      dirs.push(desc.directory.getBaseName())

      if dirs.length is 3
        expect(dirs).toContain('bar')
        expect(dirs).toContain('foo')
        expect(dirs).toContain('parent')
      expect(dirs.length > 3).not.toBe(true)

  it 'finds a .cloud-sync.json in a parent directory', ->
    sd = null
    SyncDescription.withNearest fixtureDir('parent', 'child'), (err, desc) ->
      expect(err).toBeNull()
      sd = desc

    waitsFor -> sd?
    runs ->
      rp = sd.directory.getRealPathSync()
      expect(rp).toBe(fixturePath 'parent')

  it 'returns null if no .cloud-sync.json files exist', ->
    called = false
    SyncDescription.withNearest fixtureDir('baz'), (err, desc) ->
      expect(err).toBeNull()
      expect(desc).toBeNull()
      called = true

    waitsFor -> called

  it 'parses configuration data from .cloud-sync.json', ->
    withDescription ['bar', '.cloud-sync.json'], (sd) ->
      expect(sd.container).toBe('magic')
      expect(sd.psuedoDirectory).toBe('somedir/')
      expect(sd.public).toBe(true)

  it 'defaults the psuedoDirectory to ""', ->
    withDescription ['foo', '.cloud-sync.json'], (sd) ->
      expect(sd.psuedoDirectory).toBe('')

  it 'defaults public to false', ->
    withDescription ['foo', '.cloud-sync.json'], (sd) ->
      expect(sd.public).toBe(false)

  describe 'finding CloudCredentials', ->

    itLoadsCredentials = (path, creduser) ->
      c = null
      withDescription path, (sd) ->
        sd.withCredentials (err, creds) ->
          console.log err if err
          c = creds

      waitsFor -> c?
      runs -> expect(c.username).toBe(creduser)

    it 'finds CloudCredentials if provided locally', ->
      itLoadsCredentials ['foo', '.cloud-sync.json'], 'foo'

    it 'finds CloudCredentials by walking the filesystem', ->
      itLoadsCredentials ['bar', '.cloud-sync.json'], 'defaultuser'

  describe 'enumerating contents', ->

    it 'recursively enumerates files', ->
      paths = []

      withDescription ['parent', '.cloud-sync.json'], (sd) ->
        sd.withEachPath (err, path) ->
          if err?
            console.log err
          else
            paths.push path

      waitsFor -> paths.length is 2

      runs ->
        expect(paths).toContain fixturePath 'parent', 'inparent.txt'
        expect(paths).toContain fixturePath 'parent', 'child', 'placeholder.txt'
        expect(paths).not.toContain fixturePath(
          'parent', '.cloud-credentials.json'
        )
