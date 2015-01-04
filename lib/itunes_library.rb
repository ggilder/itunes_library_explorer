require 'benchmark'
require 'active_support/core_ext/module/delegation'

class ItunesLibrary
  attr_reader :path, :plist

  def initialize(path)
    @path = path
    time = Benchmark.realtime do
      @plist = Plist::parse_xml(path)
    end
    puts("Library %s parsed in %0.2fs." % [path, time])
  end

  def info
    Hash[
      [
        "Major Version",
        "Minor Version",
        "Date",
        "Application Version",
        "Features",
        "Show Content Ratings",
        "Music Folder",
        "Library Persistent ID",
      ].map do |key|
        [key, plist[key]]
      end
    ]
  end

  def tracks
    @tracks ||= TrackStore.new(plist['Tracks'])
  end

  def track(id)
    tracks.fetch(id)
  end

  def playlists
    @playlists ||= PlaylistStore.new(plist['Playlists'], tracks)
  end

  def playlist(id)
    playlists.fetch(id)
  end

  private

  class TrackStore
    include Enumerable

    attr_reader :all

    delegate :fetch, :each, :values, to: :all

    def initialize(data)
      @all = Hash[
        data.map do |id, track|
          [id.to_i, Track.new(track)]
        end
      ]
    end

    def to_s
      id = '%x' % (object_id << 1)
      "#<ItunesLibrary::TrackStore:0x#{id}, #{count} tracks>"
    end
    alias_method :inspect, :to_s

    def audio_files
      values.select(&:audio_file?)
    end

    class Track
      attr_reader :info

      def initialize(info)
        @info = info
      end

      def to_s
        "#{name} - #{artist}"
      end
      alias_method :inspect, :to_s

      def name
        info['Name']
      end

      def artist
        info['Artist'] || 'Unknown Artist'
      end

      def album
        info['Album'] || 'Unknown Album'
      end

      def audio_file?
        info['Kind'] =~ / audio file$/
      end
    end
  end

  class PlaylistStore
    include Enumerable

    attr_reader :all

    delegate :each, :fetch, :values, to: :all

    def initialize(data, track_store)
      @track_store = track_store

      # Playlists need to be indexed by persistent ID, even though tracks are
      # indexed by integer ID, because nesting (folders) works by persistent ID.
      # Thanks, iTunes.
      @all = Hash[
        data.map do |playlist|
          [playlist['Playlist Persistent ID'], Playlist.new(playlist, self, track_store)]
        end
      ]
      resolve_nesting!
    end

    def to_s
      id = '%x' % (object_id << 1)
      "#<ItunesLibrary::PlaylistStore:0x#{id}, #{count} tracks>"
    end
    alias_method :inspect, :to_s

    def print_nested
      puts values.select { |playlist| playlist.parent.nil? }.map(&:nested_description)
    end

    def find_by_name(name)
      values.find { |playlist| playlist.name == name }
    end

    private

    def resolve_nesting!
      each do |_id, playlist|
        if playlist.parent
          unless playlist.parent.folder?
            error = "Database inconsistency! " +
              "Playlist '#{playlist.parent.name}' (#{playlist.parent.persistent_id}) contains playlists " +
              "but is not a folder!"
            raise error
          end
          playlist.parent.playlists << playlist
        end
      end
    end

    class Playlist
      attr_reader :info, :playlists

      def initialize(info, playlist_store, track_store)
        @info = info
        @playlists = []

        @playlist_store = playlist_store
        @track_store = track_store
      end

      def to_s
        attributes = [
          ('Folder' if folder?),
          "#{count} tracks",
        ].compact
        "#{name} (#{attributes.join(', ')})"
      end
      alias_method :inspect, :to_s

      def nested_description(indent = 0)
        prefix = ' ' * indent * 2
        prefix += folder? ? '+' : '-'
        children = playlists.map { |playlist| playlist.nested_description(indent + 1) }
        "#{prefix} #{to_s}\n#{children.join}"
      end

      def persistent_id
        info['Playlist Persistent ID']
      end

      def name
        info['Name']
      end

      def count
        tracks.count
      end
      alias_method :size, :count
      alias_method :length, :count

      def tracks
        @tracks ||= parse_tracks
      end

      def folder?
        info['Folder']
      end

      def parent
        parent_id = info['Parent Persistent ID']
        playlist_store.fetch(parent_id) if parent_id
      end

      private

      attr_reader :playlist_store, :track_store

      def parse_tracks
        (info['Playlist Items'] || []).map do |item|
          track_store.fetch(item['Track ID'])
        end
      end
    end
  end
end
