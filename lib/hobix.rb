#
# = hobix.rb
#
# Hobix command-line weblog system.
#
# Copyright (c) 2003-2004 why the lucky stiff
#
# Written & maintained by why the lucky stiff <why@ruby-lang.org>
#
# This program is free software. You can re-distribute and/or
# modify this program under the same terms of ruby itself ---
# Ruby Distribution License or GNU General Public License.
#
#--
# $Id$
#++
require 'hobix/config'
require 'hobix/weblog'

# = Hobix
#
# Hobix is a complete blogging system, designed to be managed
# on the file system and accessed through a command-line application.
# 
# The command-line application is powered by this Ruby library
# which is designed to be fully scriptable and extensible.  
#
# == Example 1: Regenerating a weblog
#
# Vim is a text editor that can be scripted by Ruby.  One great
# script for Vim would be a script that could load one of your
# templates for editing and fire a regeneration when the file
# is saved.  Any editor, or even an IDE such as FreeRIDE, could
# be scripted to do the same quite easily.
#
# The first step is to load the Weblog object.
#
#   require 'hobix/weblog'
#   weblog = Hobix::Weblog.load( '/my/blahhg/hobix.yaml' )
#
# With the weblog loaded, we'll now want to load a template.
# Templates are stored in the weblog's +skel_path+ accessor.
#
#   tpl_path = File.join( weblog.skel_path, 'index.html.erb' )
#
# We give the path to the editor.  When we are done editing,
# the editor saves to the original path.  We can then trigger
# a rebuild.
#
#   weblog.regenerate :update
#
# The :update indicates that not every file will be regenerated,
# only those affected by the change.
#
# == Example 2: E-mail notify on publish
#
# Publisher plugins are used to perform actions when the site
# has an upgen or regen.  Hobix plugins are absolutely the simplest
# Ruby coding ever.  Watch.
#
#   require 'net/smtp'
#
#   module Hobix::Publish
#   class Email < Hobix::BasePublish
#     def initialize( weblog, emails ); end
#     def watch; ['entry']; end
#     def publish( page_name ); end
#   end
#   end
#
# This plugin doesn't do anything yet.  But it won't throw any errors.
# This is our skeleton for a plugin that will e-mail us when there are
# updates to the site.
#
# The +watch+ method monitors certain page prefixes.  The `entry' prefix
# indicates that this publish plugin looks for changes to any entry on
# the site.
#
# The +initialize+ method is important as well.  It receives the
# +Hobix::Weblog+ object the publishing took place on.  The _emails_
# parameter is supplied a list of e-mail address from the weblog's
# hobix.yaml configuration.
#
# When a plugin is initialized it is given the weblog object and
# any data which is supplied in the weblog configuration.  Here is
# what the hobix.yaml looks like:
#
#   requires:
#     - hobix/storage/filesys
#     - hobix/out/erb
#     - hobix/publish/ping: [http://ping.blo.gs:80/]
#
# In the above configuration, an Array is passed to the Ping plugin.
# So that's what we'll receive here.
#
# To get our e-mail sending, let's fill in the +initialize+ and
# +publish+ methods.
#
#   def initialize( weblog, emails )
#     @weblog = weblog
#     @emails = emails
#   end
#   def publish( page_name )
#     Net::SMTP.start( 'localhost', 25 ) do |smtp|
#       @emails.each do |email|
#         smtp.send_message <<MSG, 'your@site.com', email
#   From: your@site.com
#   To: #{ email }
#
#   The site has been updated.
#   MSG
#       end
#     end    
#   end
#
# = Module Map
#
# Here is a map of the core modules which are loaded when you
# require 'hobix' in your script.
#
# Hobix::Weblog::       Generally, this module is the starting point.
#                       Load a weblog's configuration into a Hobix::Weblog
#                       object, which can be used to query entries, 
#                       generate pages, and edit any part of the site.
#                       (from 'hobix/weblog')
#
# Hobix::Entry::        Using an entry's id (or shortName), you can
#                       load Entry objects, which contain all the
#                       content and rendering details for an entry.
#                       (from 'hobix/entry')
#
# Hobix::EntryEnum::    When Hobix supplies a template with a list of
#                       entry classes, this module is mixed in.
#                       (from 'hobix/entry')
#
# Hobix::LinkList::     An Entry subclass, used for storing links.
#                       (from 'hobix/linklist')
#
# Hobix::BasePlugin::   All Hobix plugins inherit from this class.
#                       The class uses Ruby's +inherited+ hook to
#                       identify plugins.
#                       (from 'hobix/base')
#
# Hobix::BaseStorage::  All storage plugins inherit from this class.
#                       Storage plugins exclusively store the weblog entries.
#                       (from 'hobix/base')
#
# Hobix::BaseOutput::   All output plugins inherit from this class.
#                       Output plugins are attached to specific template
#                       types and they feed entries into the template.
#                       (from 'hobix/base')
#
# Hobix::BasePublish::  All publisher plugins inherit from this class.
#                       Publisher plugins are notified when certain
#                       pages are updated.  For example, the +ping+
#                       plugin will ping blog directories if the `index'
#                       pages are updated.
#                       (from 'hobix/base')
#
# Hobix::Config::       Users individually store their personal settings
#                       and weblog paths in .hobixrc.  This class
#                       is used to load and manipulate the settings file.
#                       (from 'hobix/config')
#
# Hobix comes with a few plugins, for which documentation is also
# available.
#
# Hobix::Storage::Filesys::  This plugin stores entries in separate YAML
#                            files.  Directories can be used to categorize
#                            and organize entries.
#                            (from 'hobix/storage/filesys')
#
# Hobix::Out::ERB::          This output plugin handles .erb templates.
#                            Page and entry data are passed in as variables.
#                            ERuby markup is used in the document to script
#                            against those variables.
#                            (from 'hobix/out/erb')
#
# Hobix::Out::RedRum::       This output plugin handles .redrum templates.
#                            These templates contain ERuby as well.  The output
#                            generated by the page is passed through RedCloth,
#                            a Textile processor.  This way, you can write
#                            your templates in Textile with ERuby scripting.
#                            (from 'hobix/out/redrum')
#
# Hobix::Out::RSS::          This output plugin handles .rss templates.
#                            These templates are empty and simply signify to
#                            the plugin that an RSS 2.0 feed should be generated
#                            for the entry data.
#                            (from 'hobix/out/rss')
#
# Hobix::Out::Atom::         This output plugin handles .atom templates.
#                            Just like the RSS plugin, but generates an Atom feed.
#                            (from 'hobix/out/atom')
#
# Hobix::Out::OkayNews::     This output plugin handles .okaynews templates.
#                            Just like the Atom and RSS plugins, but generates
#                            !okay/news, a YAML syndication feed.
#                            (from 'hobix/out/okaynews')
#
# Hobix::Publish::Ping::     This publisher plugin pings blog directories when the
#                            'index' pages are published on a regen or upgen.
#
module Hobix
    ## Version used to compare installations
    VERSION = '0.1d'
    ## CVS information
    CVS_ID = "$Id$"
    CVS_REV = "$Revision$"[11..-3]
    ## Share directory contains external data files
    SHARE_PATH = "/usr/local/share/hobix/"
end

