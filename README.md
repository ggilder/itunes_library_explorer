# iTunes Library Explorer

Interactive tool for exploring an iTunes library export.

## How to

1. File > Library > Export Library in iTunes (this seems to include a little more information than the `~/Music/iTunes/iTunes Music Library.xml` file).
1. Run `itunes_explore PATH_TO_EXPORTED_XML` and run commands on `Library`.

## Examples

    # Print tree of all playlists (shows folders with '+' and playlists with '-').
    Library.playlists.print_nested

    # Find a playlist by persistent ID
    Library.playlist('ABC123')

    # Find a playlist by name
    Library.playlists.find_by_name('Cool playlist')

    # Show tracks of a playlist
    pp Library.playlists.find_by_name('Cool playlist').tracks; nil

    # Show playlists contained in a folder playlist
    pp Library.playlists.find_by_name('Cool folder').playlists; nil

    # Show all audio file tracks
    pp Library.tracks.audio_files; nil

Both playlists and tracks have a `info` method to return the raw information from the library XML.
