module.exports =
# Model corresponding to a dotfile that describes where and how a directory
# should be synchronized with a cloud storage container.
class SyncDescription

  constructor: (@directory) ->

  # Scan the filesystem for directories containing ".cloud-sync.json" files.
  # Parse each one into a SyncDescription and send it to a callback.
  @findAll: (callback) -> @findAllIn(atom.project.getRootDirectory(), callback)

  @findAllIn: (root, callback) ->
    root.getEntries (err, entry) =>
      return callback(err, null) if err

      if entry instanceof Directory
        @findAllIn(entry, callback)
      else
        callback(null, root) if entry.getBaseName() is '.cloud-sync.json'
