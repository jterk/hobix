#
# = hobix/plugin/comment-notification.rb
#
# Copyright 2009, Jason Terk <jason.terk@gmail.com>
#
# This program is free software, released under a BSD license.
# See COPYING for details.
#
# This simple plugin will email all of a blog's configured authors upon
# submission of a new comment.
#
# Enable by including the following in the requires section of hobix.yaml:
#
#   - hobix/plugin/comment-notification
#
# TODO: The commenting system needs better hooks - right now a plugin to be
# run on new comments must be wired into the comments facet directly.
#
require 'net/smtp'

module Hobix
  class CommentNotification < BasePlugin
    def initialize(weblog, params = {})
      raise "The comment-notification plugin requires an SMTP server." unless params.member? 'smtp_server'
      @@smtp_server = params['smtp_server']
      @@smtp_port = params['smtp_port'] or 25
      @@smtp_user = params['smtp_user']
      @@smtp_password = params['smtp_password']

      @@from_address = "comment-notifier@#{weblog.link.host}"
    end

    def self.notify(weblog, entry_id, comment)
      # Build a link to the entry.
      link = weblog.output_entry_map[entry_id]
      url = weblog.expand_path( link[:page].link )

      weblog.authors.each_value do |author|
        email = <<END_OF_MESSAGE
From: Comment Notifier <#{@@from_address}>
To: #{author['name']} <#{author['email']}>
Subject: There's a new comment on #{weblog.title} from #{comment.author}
Date: #{comment.created.rfc2822}

Hey there #{author['name']},

Someone going by the name #{comment.author} (IP Address: #{comment.ipaddress},
Email Address:#{comment.email}) just posted a comment to the entry <a href="#{url}">#{entry_id}</a>.

- Your friendly neighborhood email notifier.
END_OF_MESSAGE

        begin
          if @@smtp_user
            Net::SMTP.start(@@smtp_server, @@smtp_port, "localhost.localdomain", @@smtp_user, @@smtp_password, :plain) do |smtp|
              smtp.send_message email, @@from_address, "#{author['email']}"
            end
          else
            Net::SMTP.start(@@smtp_server, @@smtp_port) do |smtp|
              smtp.send_message email, @@from_address, "#{author['email']}"
            end
          end
        rescue Exception => e
          $stderr.puts e.message
        end
      end
    end
  end
end
