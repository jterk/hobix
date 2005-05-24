#
# = hobix/commandline.rb
#
# Hobix command-line weblog system.
#
# Copyright (c) 2003-2004 why the lucky stiff
#
# Written & maintained by why the lucky stiff <why@ruby-lang.org>
#
# This program is free software, released under a BSD license.
# See COPYING for details.
#
#--
# $Id$
#++
require 'hobix'
require 'hobix/api'

module Hobix
module CommandLine
    include APIMethods

    ##
    ## Locate RC
    ##
    [
        [ENV['HOME'], ENV['HOME']],
        [ENV['APPDATA'], File.join( ENV['APPDATA'], 'Hobix' )]
    ].each do |home_top, home_dir|
        next unless home_top
        if File.exists? home_top
            File.makedirs( home_dir )
            HOME_DIR = home_dir
            break
        end
    end
    RC = File.join( HOME_DIR, '.hobixrc' )

    def CommandLine.extended( o )
      #
      # When extended we should get all required plugin for the 
      # whole Hobix stuff
      #
      return unless File.exists? RC

      config = YAML::load( File.open( RC ) )
      
      #
      # Add a new instance variable to o
      #
      o.instance_variable_set( :@config, config )

      #
      # Eventually add user specified path
      #
      if config['libs']
        config['libs'].each do |p|
          if File.exists?( p ) && File.directory?( p )
            $LOAD_PATH << p
          else
            warn "#{p} not loaded. Either inexistant or not a directory"
          end
        end
      end

      #
      # And system wide path too
      #
      if File.exists?( Hobix::SHARE_PATH )
        $LOAD_PATH << File.join(Hobix::SHARE_PATH,"lib")
      end
      
      #
      # Load plugins if necessary
      #
      if config['requires']
        config['requires'].each do |req|
          Hobix::BasePlugin::start( req, self )
        end
      end
      
    end

    def gets;          $stdin.gets;          end
    def puts( *args ); $stdin.puts( *args ); end

    def login( config = nil )
        config ||= RC
        @config = File.open( config ) { |f| YAML::load( f ) } if File.exists? RC
        setup unless @config
        setup_personal unless @config['personal']
    end

    def config
        @config
    end

    def save_config
        File.open( RC, "w" ) do |f|
            f.write @config.to_yaml
        end
    end

    # Update your Hobix setup
    def upgrade_app_explain; "Check for updates to Hobix."; end
    def upgrade_app_args; []; end
    def upgrade_app( config )
        require 'rbconfig'
        require 'open-uri'
        c = ::Config::CONFIG.merge( config )
        eval(open("http://go.hobix.com/").read)
    end

    # List all your weblogs
    def blogs_weblog_explain; "List your weblogs."; end
    def blogs_weblog_args; []; end
    def blogs_weblog
        if @config['weblogs'].respond_to? :sort
            blogs = @config['weblogs'].sort
            name_width = blogs.collect { |b| b[0].length }.max
            tabular( blogs, [[-name_width, 0, 'weblog-name'], [-40, 1, 'path']] )
        else
            puts "** You have no blogs set up.  Use `hobix setup_blogs' to get started."
        end
    end

    # Create a new skeleton for a weblog
    def create_weblog_explain; "Create a brand new weblog."; end
    def create_weblog_args; ['weblog-name', '/path/to/']; end
    def create_weblog( name, path )
        @config['weblogs'] ||= {}
        if @config['weblogs'][name]
            print "*** Blog '#{ name }' exists already! Overwrite?? [y/N]: "
            if gets.strip.upcase != 'Y'
                puts "*** Creation of weblog `#{ name }' aborted."
                return
            end
        end
        path = File.expand_path( path )
        puts <<-NOTE
        |*** Creation of weblog `#{ name }' will add the following directory"
        |    structure to directory #{ path }"
        |
        |    #{ path }
        |       hobix.yaml <- configuration
        |       
        |       entries/   <- edit and organize
        |                     your news items,
        |                     articles and so on.
        |       
        |       skel/      <- contains your
        |                     templates
        |       
        |       htdocs/    <- html is created here,
        |                     store all your images here,
        |                     this is your viewable
        |                     websyht
        |       
        |       lib/       <- extra hobix libraries
        |                     (plugins) go here
        |
        NOTE
        print "Create this structure? [y/N]: "
        if gets.strip.upcase != 'Y'
            puts "*** Creation of weblog `#{ name }' aborted."
            return
        end

        modes = File.open( "#{ Hobix::SHARE_PATH }/default-blog-modes.yaml" ) { |f| YAML::load( f ) }

        puts "The default blog is available in the following modes:"
        puts "  #{ modes.keys.join( ', ' ) }"
        puts
        mode = nil
        loop do
            print "Modes: [Comma between each mode or Enter for none] "
            mode = gets.strip.downcase
            m = mode
            break if mode.empty? or not mode.split( /,/ ).detect { |m| m.strip!; not modes.has_key?( m ) }
            puts "*** No `#{ m }' mode available."
        end

        require 'fileutils'
        FileUtils.makedirs path
        FileUtils.cp_r Dir.glob( "#{ Hobix::SHARE_PATH }/default-blog/*" ), path

        # apply any patches
        patchlist = mode.split( /,/ ).map { |m| modes[m.strip] }.flatten.uniq
        require 'hobix/util/patcher'
        patchlist.collect! { |p| "#{ Hobix::SHARE_PATH }/default-blog.#{ p }.patch" }
        patcher = Hobix::Util::Patcher[ *patchlist ]
        patcher.apply( path )

        hobix_yaml = File.join( path, "hobix.yaml" )
        join_as_author( name, hobix_yaml )
        edit_action( Hobix::Weblog.load( hobix_yaml ) )
    end


    # Add a weblog to local config
    def add_weblog_explain; "Adds a pre-existing hobix weblog to your list."; end
    def add_weblog_args; ['weblog-name', '/path/to/hobix.yaml']; end
    def add_weblog( name, path )
        @config['weblogs'] ||= {}
        path = File.expand_path( path )
        puts "*** Checking for existence of blog."
        require 'hobix/weblog'
        if File.directory? path
            path = File.join( path, 'hobix.yaml' )
            puts "*** Path is a directory, using `#{ path }'."
        end
        unless File.exists? path
            puts "*** No file `#{ path }' found!  Aborting."
            return
        end
        join_as_author( name, path )
    end

    def join_as_author( name, path )
        weblog = Hobix::Weblog.load( path )
        puts "*** Joining blog `#{ weblog.title }', adding you as author."
        weblog.authors[@config['username']] = @config['personal']
        weblog.save( path )
        @config['weblogs'][name] = path
        save_config
    end

    def edit_action( weblog )
        path = weblog.hobix_yaml
        weblog = aorta( weblog )
        return if weblog.nil?
        weblog.save( path )
    end

    # Delete a weblog from local config
    def del_weblog_explain; "Remove weblog from your list."; end
    def del_weblog_args; ['weblog-name']; end
    def del_weblog( name )
        @config['weblogs'] ||= {}
        @config['weblogs'].delete( name )
        save_config
    end

    # Run a DRuby daemon for blogs in your configuration
    def druby_weblog_explain; "Start the DRuby daemon for weblogs in your config."; end
    def druby_weblog_args; []; end
    def druby_weblog
        if @config['weblogs']
            unless @config['druby']
                @config['druby'] = 'druby://:4081'
                puts "** No drb url found, using #{ @config['druby'] }"
            end
            require 'drb'
            blogs = {}
            @config['weblogs'].each do |name, path|
                blogs[name] = Hobix::Weblog.load path
            end
            api = Hobix::API.new blogs
            DRb.start_service @config['druby'], api
            DRb.thread.join
        else
            puts "** No blogs found in the configuration."
        end
    end

    # List entries
    def list_action_explain; "List all posts within a given path."; end
    def list_action_args; ['weblog-name', 'search/path']; end
    def list_action( weblog, inpath = '' )
        entries = weblog.storage.find( :all => true, :inpath => inpath )
        if entries.empty?
            puts "** No posts found in the weblog for path '#{inpath}'."
        else
            entries.sort { |e1, e2| e1.id <=> e2.id }
            name_width = entries.collect { |e| e.id.length }.max
            rows = entries.inject([]) { |rows, entry| rows << [entry.id, entry.created] }
            tabular( rows, [[-name_width, 0, 'shortName'], [-34, 1, 'created']] )
        end
    end

    # Post a new entry
    def post_action_explain; "Add or edit a post with identifier 'shortName'.\n" +
        "(You can use full paths. 'blog/weddings/anotherPatheticWedding')"; end
    def post_action_args; ['weblog-name', 'shortName']; end
    def post_action( weblog, entry_id )
        begin
            entry = weblog.storage.load_entry( entry_id )
        rescue Errno::ENOENT
            entry = weblog.entry_class.new
            entry.author = @config['username']
            entry.title = entry_id.split( '/' ).
                                   last.
                                   gsub( /^\w|_\w|[A-Z]/ ) { |up| " #{up[-1, 1].upcase}" }.
                                   strip
        end
        entry = aorta( entry )
        return if entry.nil?

        weblog.storage.save_entry( entry_id, entry )
        weblog.regenerate( :update ) if @config['post upgen']
    end

    ##          
    ## Setup user's RC
    ##
    def setup
        @config = {}
        puts "Welcome to hobix (a simple weblog tool).  Looks like your" 
        puts "first time running hobix, eh?  Time to get a bit of information"
        puts "from you before you start using hobix.  (All of this will be stored"
        puts "in the file #{ Hobix::CommandLine::RC } if you need to edit.)"
        puts

        username = ''
        default_user = ''
        user_prompt = 'Your hobix username'
        if ENV['USER']
            default_user = ENV['USER']
            user_prompt << " [<Enter> for #{ ENV['USER'] }]"
        end
        while username.empty?
            puts
            print "#{ user_prompt }: "
            username = gets.strip
            if username.empty?
                username = default_user
            end
        end
        @config['username'] = username

        puts
        puts "Your EDITOR environment variable is set to '#{ ENV['EDITOR'] }'."
        puts "You can edit entries with your EDITOR or you can just use hobix."
        puts "** NOTE: If you don't use your own editor, then you will be using"
        puts "   the Hobix built-in object editor, which is highly experimental"
        puts "   and may not work on your platform.)"
        print "Use your EDITOR to edit entries? [Y/n]: "
        editor = gets.strip.upcase

        if editor == 'N'
            @config['use editor'] = false
        else
            @config['use editor'] = true
        end

        puts
        puts "After posting a new entry, would you like Hobix to automatically"
        print "update the site? [Y/n]: "
        post_upgen = gets.strip.upcase

        if post_upgen == 'N'
            @config['post upgen'] = false
        else
            @config['post upgen'] = true
        end
        save_config
    end

    ##
    ## Setup personal information
    ##
    def setup_personal
        @config['personal'] ||= {}
        puts
        puts "Your personal information has not been setup yet."
        [['name', 'Your real name', true], 
         ['url', 'URL to your home page', false],
         ['email', 'Your e-mail address', false]].each do |k, txt, req|
            print "#{ txt }: "
            val = gets.strip
            retry if req and val.empty?
            @config['personal'][k] = val
        end
        save_config
    end

    ##
    ## Extra setup, triggered upon installation
    ##
    def setup_blogs
        puts
        puts "            === Joining an existing weblog? ==="
        puts "If you want to join an existing hobix weblog, we can do that now."
        puts "Each weblog needs a name and a path.  Use <ENTER> at any prompt"
        puts "to simply move on."
        loop do
            puts
            puts "Short name for weblog, used on the command line (i.e. hobix upgen blogName)."
            print ": "
            blogname = gets.strip
            break if blogname.empty?

            print "Path to weblog's hobix.yaml `#{ blogname }': "
            blogpath = gets.strip
            if blogpath.empty?
                puts "*** Aborting setup of weblog `#{ blogname }'."
                break
            end
            add_weblog( blogname, blogpath )
        end

        puts "To setup more weblogs later, use: hobix add #{ add_weblog_args.join( ' ' ) }"
        puts
        puts "            === Create a new weblog? ==="
        puts "If you want to create a new hobix weblog, we can do that now."
        puts "Each weblog needs a name and a path.  Use <ENTER> at any prompt"
        puts "to simply move on."
        loop do
            puts
            puts "Short name for weblog, used on the command line (i.e. hobix upgen blogName)."
            print ": "
            blogname = gets.strip
            break if blogname.empty?

            print "Path to create weblog `#{ blogname }': "
            blogpath = gets.strip
            if blogpath.empty?
                puts "*** Aborting creation of weblog `#{ blogname }'."
                break
            end
            create_weblog( blogname, blogpath )
        end
        puts "To create more weblogs later, use: hobix create #{ create_weblog_args.join( ' ' ) }"
        puts
    end

    def aorta( obj )
        if @config['use editor']
            tempfile = File.join(ENV['TMPDIR']||ENV['TMP']||ENV['TEMP']||'/tmp',"%10.6f.hobix" % Time.now())
            File.open( tempfile, 'w' ) { |f| f << obj.to_yaml }
            created = File.mtime( tempfile )
            system( "#{ ENV['EDITOR'] || 'vi' } #{ tempfile }" )
            return nil unless File.exists?( tempfile )

            if created < File.mtime( tempfile )
                obj = YAML::load( File.open( tempfile ) )
            else
                puts "** Edit aborted"
                obj = nil
            end
            File.delete( tempfile )
        else
            require 'hobix/util/objedit'
            obj = Hobix::Util::ObjEdit( obj )
        end
        obj
    end

    def tabular( table, fields, desc = nil )
        field_widths = fields.collect do |width, id, title|
            ([width.abs, title.length].max + 1) * ( width / width.abs )
        end
        client_format = field_widths.collect { |width| "%#{ width}s"}.join( ': ')
        puts client_format % fields.collect { |width, id, title| title }
        puts field_widths.collect { |width| "-" * width.abs }.join( ':-' )
        table.each do |row|
            puts client_format % fields.collect { |width, id, title| row[ id ] }
            if desc
                puts row[ desc ]
                puts
            end
        end
    end

    def puts( str = '' )
        Kernel::puts str.gsub( /^\s+\|/, '' )
    end
end
end

