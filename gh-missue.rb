#!/usr/bin/env ruby
# gh-missue.rb -- A GitHub issue migration script written in Ruby
#==================================================================================================
# Author:       E:V:A
# Date:         2018-04-10
# License:      ISC
# Formatting    UTF-8 with 4-space TAB stops and no TAB chars.
# URL:          https://github.com/E3V3A/gh-missue
# Based On:     https://github.com/TimothyBritt/github-issue-migrate
# 
# Description:  A Ruby script for migrating selected GitHub issues to your own repository and 
#               using OAuth2 authentication to increase speed and prevent rate limiting.
#
# Dependencies:
#       [1] docopt  https://github.com/docopt/docopt.rb/
#       [2] octokit https://github.com/octokit/octokit.rb/
# 
# NOTE:
#
#   1. To make this run, you need to:
#           (a) have Ruby installed
#           (b) gem install GitHubs own "octokit" library
#           (c) gem install the option parser "docopt" 
#   2. You should also consider creating a personal authentication token on GitHub,
#      to avoid getting rate-limited by a large number of requests in short time.
#
# ToDo: 
#   
#   [ ] Fix username/password authentication
#   [ ] Fix inclusion of CLI options: -d, -n  
#       -d              - show debug info with full option list, raw requests & responses etc.
#       -n  <1,3-6,9>   - only migrate issues given by the list. Can be a range.
#       
#==================================================================================================

# Use Ruby3 "frozen" in Ruby2
# frozen_string_literal: true

#require './lib/issue_migrator.rb'
#require 'pp

require 'docopt'
require 'octokit'

require 'net/http'
require 'uri'
require 'json'

VERSION = '1.0.1'
options = {}

#--------------------------------------------------------------------------------------------------
# The cli options parser
#--------------------------------------------------------------------------------------------------
doc = <<DOCOPT

  Description:

    gh-missue is a Ruby program that migrate issues from one github repository to another.
    Please note that you can only migrate issues to your own repo, unless you have an OAuth2
    authentication token.

  Usage:
        #{__FILE__} [-c | -n <ilist> | -t <itype>] <source_repo> <target_repo>
        #{__FILE__} [-c | -n <ilist> | -t <itype>] <oauth2_token> <source_repo> <target_repo>
        #{__FILE__} [-c | -n <ilist> | -t <itype>] <username> <password> <source_repo> <target_repo>
        #{__FILE__} [-d] -l <itype> [<oauth2_token>] <repo>
        #{__FILE__} -n <ilist>
        #{__FILE__} -t <itype>
        #{__FILE__} [-d] -r [<oauth2_token>]
        #{__FILE__} -d
        #{__FILE__} -v
        #{__FILE__} -h

  Options:

        -c                  - only copy all issue labels from <source> to <target> repos, including name, color and description
        -l <itype> <repo>   - list available issues of type <itype> (all,open,closed) and all labels in repository <repo>
        -t <itype>          - specify what type (all,open,closed) of issues to migrate. [default: open]
        -r                  - show current rate limit and authentication method for your IP
        -d                  - show debug info with full option list, raw requests & responses etc.
        -n <ilist>          - only migrate issues with comma separated numbers given by the list. Can include a range.
        -h, --help          - show this help message and exit
        -v, --version       - show version and exit

  Examples:

        #{__FILE__} -r
        #{__FILE__} -l open E3V3A/MMM-VOX
        #{__FILE__} -t closed "E3V3A/TESTO" "USERNAME/REPO"
        #{__FILE__} -n 1,4-5 "E3V3A/TESTO" "USERNAME/REPO"

  Dependencies:
        #{__FILE__} depends on the following gem packages: octokit, docopt.

DOCOPT

#--------------------------------------------------------------------------------------------------
# The IssueMigrator
#--------------------------------------------------------------------------------------------------
class IssueMigrator

    # attr_accessor :issues, :client, :target_repo, :source_repo
    attr_accessor :access_token, :issues, :ilist, :itype, :client, :target_repo, :source_repo

    def initialize(access_token, source_repo, target_repo)
        @client = Octokit::Client.new( :access_token => access_token, 
            # :accept => 'application/vnd.github.symmetra-preview+json',
            # :headers => { "X-GitHub-OTP" => "<your 2FA token>" }
            per_page: 100 )

            # // Personal OAuth2 Access Token
            #:access_token => "YOUR_40_CHAR_OATH2_TOKEN"

            # // Standard GitHub Credentials
            #:login => username,
            #:password => password

            # // OAuth2 App Credentials
            #:client_id     => "<YOUR_20_CHAR_OATH2_ID>",
            #:client_secret => "<YOUR_40_CHAR_OATH2_SECRET>"

        user = client.user
        user.login
        @source_repo = source_repo
        @target_repo = target_repo
        @itype = itype
    end

    def pull_source_issues(itype) # ilist => nil ??
        @client.auto_paginate = true
        @issues = @client.issues(@source_repo, :state => itype)     # The issue type:   <itype>: [open/closed/all]
        # @issues = @client.issues(@source_repo, :issue => ilist)   # The issue list:   <ilist>: "1,2,5-7,19"
        puts "Found #{issues.size} issues of type: #{itype}\n"
    end

    def list_source_issues(itype)
        pull_source_issues(itype)
        @issues.each do |source_issue|
            puts "[#{source_issue.number}]\t  #{source_issue.title}"
        end
        puts
    end

    def list_source_labels
        @client.auto_paginate = true
        @labels = @client.labels(@source_repo.freeze, accept: 'application/vnd.github.symmetra-preview+json')
        puts "Found #{@labels.size} issue labels:"
        @labels.each do |label|
            puts "[#{label.color}]  #{label.name} :  #{label.description}"
        end
        puts
    end

    def create_target_labels
        @client.auto_paginate = true
        @source_labels = @client.labels(@source_repo.freeze, accept: 'application/vnd.github.symmetra-preview+json')
        # @target_labels = @client.add_label(@target_repo.freeze, accept: 'application/vnd.github.symmetra-preview+json')
        puts "Found #{@source_labels.size} issue labels in <source_repo>:"
        puts "Copying labels..."
        tlabel = "" # nil
        @source_labels.each do |lbl|
            puts "[#{lbl.color}]  #{lbl.name} :  #{lbl.description}"
            #tlabel = {"name": lbl.name, "description": lbl.description, "color": lbl.color}
            #tlabel = {lbl.name, lbl.color, description: lbl.description}
            #lab = client.add_label(@target_repo.freeze, accept: 'application/vnd.github.symmetra-preview+json', tlabel)
            lab = client.add_label(@target_repo.freeze, lbl.name, lbl.color, accept: 'application/vnd.github.symmetra-preview+json', description: lbl.description)
            sleep(2)
        end
        puts "done."
    end

    def push_issues
        @issues.reverse!
        n = 0
        @issues.each do |source_issue|
            n += 1
            print "Processing issue: #{source_issue.number}  (#{n}/#{issues.size})\r"
            source_labels = get_source_labels(source_issue)
            source_comments = get_source_comments(source_issue)
            if !source_issue.key?(:pull_request) || source_issue.pull_request.empty?
                target_issue = @client.create_issue(@target_repo, source_issue.title, source_issue.body, {labels: source_labels})
                push_comments(target_issue, source_comments) unless source_comments.empty?
                @client.close_issue(@target_repo, target_issue.number) if source_issue.state === 'closed'
            end
            # We need to set a rate limit, even for OA2, it is 0.5 [req/sec]
            sleep(90) if ( issues.size > 1 ) # [sec]
        end
        puts "\n"
    end

    # API bug:  missing color/description
    def get_source_labels(source_issue)
        labels = []
        source_issue.labels.each do |lbl|
            labels << {"name": lbl.name, "description": lbl.description, "color": lbl.color}
        end
        #puts "Labels: #{labels}"
        labels
    end

    def get_source_comments(source_issue)
        comments = []
        source_comments = @client.issue_comments(@source_repo, source_issue.number)
        source_comments.each do |cmt|
            comments << cmt.body
        end
        comments
    end

    def push_comments(target_issue, source_comments)
        source_comments.each do |cmt|
            @client.add_comment(@target_repo, target_issue.number, cmt)
        end
    end
end

#--------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------

#if __FILE__ == $0
begin

    def sort_list(ilist)
        # "12,3-5,2,6,35-38" --> [2,3,4,5,6,12,35,36,37,38]
        ilist.gsub(/(\d+)-(\d+)/) { ($1..$2).to_a.join(',') }.split(',').map(&:to_i).sort.uniq
    end

    options = Docopt::docopt(doc, version: VERSION) # help: true

    if options['-d']
        debug = true
        #pp Docopt::docopt(doc, version: VERSION)
        puts "\nAvailable options are:\n#{options.inspect}\n"
        puts "\nThe supplied CLI options were:\n#{ARGV.inspect}\n\n"
    end

    if options['<oauth2_token>'] 
        access_token = options['<oauth2_token>']
        if access_token.size != 40 
            puts "Error: The github access token has to be 40 characters long!"
            exit
        else 
            puts "Using access_token: #{access_token}" if options['-d']
        end
    end

    # -l <itype> <source_repo>
    if ( options['-l'] )
        itype = options['-l']
        source_repo =  options['<repo>']
        target_repo = "E3V3A/TESTT" # a dummy repo
        im = IssueMigrator.new("#{access_token}", "#{source_repo}", "#{target_repo}")
        im.list_source_issues(itype)
        im.list_source_labels
    end

    # -n <ilist>
    if ( options['-n'] )
        ilist = options['-n']
        puts "The \"-n\" option has not yet been implemented!"
        puts "The supplied issue list: #{ilist}"
        #sorted = ilist.split(",").sort_by(&:to_i)
        sorted = sort_list(ilist)
        puts "The sorted issue list  : #{sorted}"
    end

    # -r / curl -i -G 'https://api.github.com/rate_limit?access_token=xxxx'
    if ( options['-r'] )
        if (access_token)
            puts "Using access_token: #{access_token}" 
            uri = URI.parse("https://api.github.com/rate_limit?access_token=#{access_token}")
        else 
            uri = URI.parse("https://api.github.com/rate_limit")
        end
        res = Net::HTTP.get_response(uri) 
        if (res.message != "OK")    # 200
            puts "ERROR: Bad reponse code: #{res.code}\n"
            puts res.body
        else
            puts "\nResponse:"
            #debug = false
            if (debug)
                #puts "\nResponse:\nHeader:\n#{res.header}\n}" # not working?
                puts "Headers:\n#{res.to_hash.inspect}\n}"
                puts "Body:\n#{res.body}\n\n}"
            end
            rbr = JSON.parse(res.body)['rate']
            RT = Time.at(rbr['reset'])
            puts "Rate limit : #{rbr['limit']}"
            puts "Remaining  : #{rbr['remaining']}"
            puts "Refresh at : #{RT}"
        end
    end
    
    # MAIN
    if ( options['<source_repo>'] and options['<target_repo>'] )
        itype = options['-t']
        #ilist = options['-n']
        #puts "<itype>: #{itype}"  # debug
        source_repo = options['<source_repo>']
        target_repo = options['<target_repo>']
        im = IssueMigrator.new("#{access_token}", "#{source_repo}", "#{target_repo}")
        if options['-c']
            im.create_target_labels
            exit
        end
        #exit if options['-c']
        im.pull_source_issues(itype)    # add ilist
        #im.list_source_issues(itype)   # 
        im.push_issues
    end

rescue Docopt::Exit => e
    puts e.message
    #puts e.backtrace.inspect
end

puts "\nDone!\n"
